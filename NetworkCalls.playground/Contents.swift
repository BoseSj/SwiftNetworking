import Foundation


/// API Endpoint Model
struct APIConfig {
    static let baseURL = "https://fakestoreapi.com"
}

enum APIEndpoint {
    enum Product {
        static let all = "/products"
        static func productById(_ id: Int) -> String {
            return "/products/\(id)"
        }
    }
    
    enum Cart {
        static let all = "/carts"
        static func cartById(_ id: Int) -> String {
            return "/carts/\(id)"
        }
    }
    
    enum Auth {
        static let login = "/auth/login"
    }
}

/// Basic Error Handling
enum APIError: Error {
    case invalidURL
    case responseError
    case decodingError
    case encodingError
}

/// Custom HTTP Methods
enum HTTPMethod: String {
    case GET
    case POST
    case PUT
    case DELETE
}

/// Custom Request
protocol Request {
    associatedtype Body: Encodable
    var endPoint: String { get }
    var method: HTTPMethod { get }
    var headers: [String: String]? { get }
    var queryParams: [String: String]? { get }
    var bodyParams: Body? { get }
}

struct APIRequest<Body: Encodable>: Request {
    let endPoint: String
    let method: HTTPMethod
    let headers: [String: String]?
    let queryParams: [String: String]?
    let bodyParams: Body?
    
    init(
        endPoint: String,
        method: HTTPMethod,
        headers: [String: String]? = nil,
        queryParams: [String: String]? = nil,
        bodyParams: Body? = nil
    ) {
        self.endPoint    = endPoint
        self.method      = method
        self.headers     = headers
        self.queryParams = queryParams
        self.bodyParams  = bodyParams
    }
}

/// When dont need to share any body param
struct EmptyBody: Encodable {}


/// Creating a Singleton API Service Class
struct APIService {
    static let shared = APIService()
    
    private init() {}
    
    func request<T: Decodable, Body: Encodable>(
        request: APIRequest<Body>,
        model: T.Type,
        completion: @escaping @Sendable (Result<T, APIError>) -> Void
    ) {
        var fullURLString = APIConfig.baseURL + request.endPoint
        
        // Query parameters to the URL for GET requests, if any
        if let queryParams = request.queryParams, request.method == .GET {
            let queryItems = queryParams.map { URLQueryItem(name: $0.key, value: $0.value) }
            var urlComponents = URLComponents(string: fullURLString)
            urlComponents?.queryItems = queryItems
            fullURLString = urlComponents?.url?.absoluteString ?? fullURLString
        }
        
        // Check url validity after adding query parameters
        guard let url = URL(string: fullURLString) else {
            completion(.failure(.invalidURL))
            return
        }
        
        // Configure httpMethod
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method.rawValue
        
        // Add headers, if any
        if let headers = request.headers {
            headers.forEach { urlRequest.setValue($1, forHTTPHeaderField: $0) }
        }
        
        // Add body parameters for non-GET requests, if any
        if let bodyParams = request.bodyParams, request.method != .GET {
            do {
                urlRequest.httpBody = try JSONEncoder().encode(bodyParams)
                urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
            }
            catch {
                completion(.failure(.encodingError))
                return
            }
        }
        
        let task = URLSession.shared.dataTask(with: urlRequest) { data, response, error in
            if let _ = error {
                completion(.failure(.responseError))
                return
            }
            
            guard let response = response as? HTTPURLResponse, (200...299).contains(response.statusCode) else {
                completion(.failure(.responseError))
                return
            }
            
            guard let data = data else {
                completion(.failure(.responseError))
                return
            }
            
            let decoder = JSONDecoder()
            do {
                let decodedData = try decoder.decode(T.self, from: data)
                completion(.success(decodedData))
            } catch {
                completion(.failure(.decodingError))
            }
        }
        
        task.resume()
    }
}



/// Dealing with the Products

/// Product Model
struct Product: Codable {
    let id: Int
    let title: String
}

func fetchAllProducts() {
    APIService.shared
        .request(
            request: APIRequest<EmptyBody>(endPoint: APIEndpoint.Product.all, method: .GET),
            model: [Product].self) { result in
                switch result {
                    case .success(let products):
                    print(products)
                case .failure(let err):
                    print(err)
                }
            }
}

func fetchSingleProduct(id: Int) {
    APIService.shared
        .request(
            request: APIRequest<EmptyBody>(endPoint: APIEndpoint.Product.productById(id), method: .GET),
            model: Product.self) { result in
                switch result {
                case .success(let product):
                    print(product)
                case .failure(let err):
                    print(err)
                }
            }
}



/// Dealing with the carts

/// Cart Model
struct Cart: Codable {
    var id: Int
    var userId: Int
    var date: String
    
    var products: [CartProduct]
}

struct CartProduct: Codable {
    var productId: Int
    var quantity: Int
}


func fetchCarts() {
    APIService.shared
        .request(
            request: APIRequest<EmptyBody>(endPoint: APIEndpoint.Cart.all, method: .GET),
            model: [Cart].self) { result in
                switch result {
                case .success(let carts):
                    print(carts)
                case .failure(let err):
                    print(err)
                }
            }
    
}

func fetchSingleCart(id: Int) {
    APIService.shared
        .request(
            request: APIRequest<EmptyBody>(endPoint: APIEndpoint.Cart.cartById(id), method: .GET),
            model: Cart.self) { result in
                switch result {
                case .success(let cart):
                    print(cart)
                case .failure(let err):
                    print(err)
                }
            }
}


/// Dealing with user authorization

/// User Login Request
struct LoginRequest: Codable {
    var username: String
    var password: String
}

/// User Login Reponse
struct Token: Codable {
    var token: String
}


/// Working on it
struct LoginRequestModel: Request {
    
    typealias Body = LoginRequest

    var endPoint: String {
        return APIEndpoint.Auth.login
    }

    var method: HTTPMethod {
        return .POST
    }

    var headers: [String : String]? {
        return nil
    }

    var queryParams: [String : String]? {
        return nil
    }

    var bodyParams: LoginRequest?
    
    init(username: String, pass: String) {
        self.bodyParams = LoginRequest(username: username, password: pass)
    }
}

func logIn(
    username: String,
    password: String
) {
    let logInReq = LoginRequest(username: username, password: password)
    
    APIService.shared
        .request(
            request: APIRequest<LoginRequest>(
                endPoint: APIEndpoint.Auth.login,
                method: .POST,
                bodyParams: logInReq
            ),
            model: Token.self
) { result in
                switch result {
                    case .success(let token):
                    print(token)
                case .failure(let err):
                    print(err)
                }
            }
}


logIn(username: "mor_2314", password: "83r5^_")
