//
//  NearbyJobsVw.swift
//  Connectar
//
//  Created by SJ Basak on 07/11/24.
//

import SwiftUI
import GoogleMaps
import CoreLocation
import Alamofire
import SwiftyJSON

// MARK: - UIViewRepresentable for GMSMapView
struct GoogleMapView: UIViewRepresentable {
    @Binding var markers: [MarkerData]
    @Binding var camera: GMSCameraPosition
    
    func makeUIView(context: Context) -> GMSMapView {
        let mapView = GMSMapView(frame: .zero, camera: camera)
        mapView.setMinZoom(1, maxZoom: 20)
        return mapView
    }
    
    func updateUIView(_ mapView: GMSMapView, context: Context) {
        mapView.camera = camera
        
        // Clear existing markers
        mapView.clear()
        
        // Add new markers
        for markerData in markers {
            let marker = GMSMarker()
            marker.position = markerData.position
            marker.title = markerData.title
            marker.snippet = markerData.snippet
            marker.icon = markerData.icon
            marker.map = mapView
        }
    }
}

// MARK: - Data Models
struct MarkerData {
    let position: CLLocationCoordinate2D
    let title: String
    let snippet: String
    let icon: UIImage?
}

// MARK: - ViewModel
class NearbyJobsViewModel: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var markers: [MarkerData] = []
    @Published var camera: GMSCameraPosition = .init(latitude: 0, longitude: 0, zoom: 10)
    @Published var showAlert = false
    @Published var alertMessage = ""
    
//    private var locationManager: CLLocationManager?
    @Published private(set) var locationManager = CLLocationManager()

    private var currentLocation: CLLocation?
    
    override init() {
        super.init()
        setupLocationManager()
    }
    
    private func setupLocationManager() {
        locationManager.delegate = self
        locationManager.requestWhenInUseAuthorization()
    }
    
    func startUpdatingLocation() {
        locationManager.startUpdatingLocation()
    }
    
    func fetchNearbyJobs() {
        guard let currentLocation = locationManager.location else {
            alertMessage = "Unable to get current location"
            showAlert = true
            return
        }
        
        let url = "http://conectar.ai/dashboard/jobCoordinates"
        
        AF.upload(
            multipartFormData: { multipartFormData in
                if let userMasterIDData = (UserModel.currentUser?.userMasterId as? String ?? "").data(using: .utf8) {
                    multipartFormData.append(userMasterIDData, withName: "user_master_id")
                }
                if let latitudeData = "\(currentLocation.coordinate.latitude)".data(using: .utf8) {
                    multipartFormData.append(latitudeData, withName: "latitude")
                }
                if let longitudeData = "\(currentLocation.coordinate.longitude)".data(using: .utf8) {
                    multipartFormData.append(longitudeData, withName: "longitude")
                }
            },
            to: url,
            method: .post
        ).responseJSON { [weak self] response in
            guard let self = self else { return }
            
            switch response.result {
                case .success(let value):
                    let resultValue = JSON(value)
                    let jobArr = resultValue["result"]["data"].arrayValue
                    
                    if jobArr.isEmpty {
                        self.alertMessage = "No Job Found Nearby"
                        self.showAlert = true
                        self.updateCamera(
                            latitude: currentLocation.coordinate.latitude,
                            longitude: currentLocation.coordinate.longitude
                        )
                    } else {
                        self.handleJobsResponse(jobArr)
                    }
                    
                case .failure(let error):
                    self.alertMessage = error.localizedDescription
                    self.showAlert = true
            }
        }
    }
    
    private func handleJobsResponse(_ jobArr: [JSON]) {
        var newMarkers: [MarkerData] = []
        
        for job in jobArr {
            if let lat = Double(job["source_lat"].stringValue),
               let long = Double(job["source_long"].stringValue) {
                let marker = MarkerData(
                    position: CLLocationCoordinate2D(latitude: lat, longitude: long),
                    title: "",
                    snippet: "",
                    icon: UIImage(named: "customMapPin")
                )
                newMarkers.append(marker)
            }
        }
        
        // Update camera to first job location
        if let firstJob = jobArr.first,
           let lat = Double(firstJob["source_lat"].stringValue),
           let long = Double(firstJob["source_long"].stringValue) {
            updateCamera(latitude: lat, longitude: long)
        }
        
        DispatchQueue.main.async {
            self.markers = newMarkers
        }
    }
    
    private func updateCamera(latitude: Double, longitude: Double) {
        DispatchQueue.main.async {
            self.camera = GMSCameraPosition.camera(
                withLatitude: latitude,
                longitude: longitude,
                zoom: 10.0
            )
        }
    }
    
    // MARK: - CLLocationManagerDelegate
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        currentLocation = location
        
        let marker = MarkerData(
            position: location.coordinate,
            title: "",
            snippet: "",
            icon: UIImage(named: "Group 62")
        )
        
        DispatchQueue.main.async {
            self.markers.append(marker)
        }
        
        locationManager.stopUpdatingLocation()
        fetchNearbyJobs()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        alertMessage = "Failed to get location: \(error.localizedDescription)"
        showAlert = true
    }
    
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        switch manager.authorizationStatus {
            case .authorizedWhenInUse, .authorizedAlways:
                locationManager.startUpdatingLocation()
            case .denied, .restricted:
                alertMessage = "Location access denied. Please enable in Settings."
                showAlert = true
            case .notDetermined:
                break
            @unknown default:
                break
        }
    }
}

// MARK: - SwiftUI View
struct NearbyJobsView: View {
    @StateObject private var viewModel = NearbyJobsViewModel()
    
    var body: some View {
        ZStack {
            GoogleMapView(
                markers: $viewModel.markers,
                camera: $viewModel.camera
            )
            .edgesIgnoringSafeArea(.all)
            
            VStack {
                HStack {
                    Button(action: {
                        // Handle back action
                    }) {
                        Image(systemName: "chevron.left")
                            .foregroundColor(.black)
                            .padding()
                            .background(Color.white)
                            .clipShape(Circle())
                    }
                    Spacer()
                }
                .padding()
                
                Spacer()
                
                Button(action: {
                    // Handle fleet job action
                }) {
                    Text("Fleet Job")
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.blue)
                        .cornerRadius(12)
                        .padding()
                }
            }
        }
        .alert(isPresented: $viewModel.showAlert) {
            Alert(
                title: Text("Notice"),
                message: Text(viewModel.alertMessage),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            viewModel.startUpdatingLocation()
        }
    }
}

#Preview {
    NearbyJobsView()
}
