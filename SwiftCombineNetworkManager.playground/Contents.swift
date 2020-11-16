import Combine
import Foundation

protocol NetworkSession: AnyObject {
    func publisher(for  request: URLRequest) -> AnyPublisher<Data, Error>
}

struct Response: Decodable {
    let name: String
}

struct ServiceError: Decodable, Error {
    let errors: [ErrorMessage]
    
    enum ErrorMessage: String, Decodable, Error {
        case invalidRequest = "invalid_request"
    }
}

class MockNetworkSession: NetworkSession {
    func publisher(for request: URLRequest) -> AnyPublisher<Data, Error> {
        let statusCode: Int
        let data: Data
        
        switch request.url?.absoluteString {
        case "https://swapi.dev/api/people/1/":
            data = """
            {
              "name": "James Bond"
            }
            """.data(using: .utf8)!
            statusCode = 200
        case "https://swapi.dev/api/planets/1/":
            data = """
            {
              "name": "Yavin IV"
            }
            """.data(using: .utf8)!
            statusCode = 200
        case "https://swapi.dev/api/starships/1/":
            data = """
            {}
            """.data(using: .utf8)!
            statusCode = 401
        case _:
            data = """
            {
              "errors": ["invalid_request"]
            }
            """.data(using: .utf8)!
            statusCode = 500
        }
        
        let response
            = HTTPURLResponse(url: request.url!, statusCode: statusCode, httpVersion: nil, headerFields: nil)!
        return Deferred {
            Future { promise in
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(Int.random(in: 1..<5)), execute: {
                    promise(.success((data: data, response: response)))
                })
            }
        }
        .setFailureType(to: URLError.self)
        .tryMap({ result in
            guard result.response.statusCode >= 200 && result.response.statusCode < 300 else {
                let error = try JSONDecoder().decode(ServiceError.self, from: result.data)
                throw error
            }
            return result.data
        })
        .eraseToAnyPublisher()
    }
}

extension URLSession: NetworkSession {
    func publisher(for request: URLRequest) -> AnyPublisher<Data, Error> {
        return dataTaskPublisher(for: request)
            .tryMap({ result in
                guard let httpResponse = result.response as? HTTPURLResponse,
                      httpResponse.statusCode >= 200 && httpResponse.statusCode < 300 else {
                    let error = try JSONDecoder().decode(ServiceError.self, from: result.data)
                    throw error
                }
                return result.data
            })
            .eraseToAnyPublisher()
    }
}

struct NetworkManager {
    private let session: NetworkSession
    
    init(session: NetworkSession) {
        self.session = session
    }
    
    func fetchPeople() -> AnyPublisher<Response, Error> {
        makePublisher(
            request: URLRequest(url: URL(string: "https://swapi.dev/api/people/1/")!)
        )
    }
    
    func fetchPlanets() -> AnyPublisher<Response, Error> {
        makePublisher(
            request: URLRequest(url: URL(string: "https://swapi.dev/api/planets/1/")!)
        )
    }
    
    func fetchStarships() -> AnyPublisher<Response, Error> {
        makePublisher(
            request: URLRequest(url: URL(string: "https://swapi.dev/api/starships/1/")!)
        )
    }
    
    func fetchPenguins() -> AnyPublisher<Response, Error> {
        makePublisher(
            request: URLRequest(url: URL(string: "https://swapi.dev/api/penguins/1/")!)
        )
    }
}

private extension NetworkManager {
    func makePublisher<T: Decodable>(request: URLRequest) -> AnyPublisher<T, Error> {
        session.publisher(for: request)
            .decode(type: T.self, decoder: JSONDecoder())
            .eraseToAnyPublisher()
    }
}

let isMocked = true
let session: NetworkSession = isMocked ? MockNetworkSession() : URLSession.shared

let fetchPeopleToken
    = NetworkManager(session: session)
    .fetchPeople()
    .sink { status in
        print("fetchPeopleToken: status received \(String(describing: status))")
    } receiveValue: { value in
        print("fetchPeopleToken: value received \(String(describing: value))")
    }

let fetchPlanetsToken
    = NetworkManager(session: session)
    .fetchPlanets()
    .sink { status in
        print("fetchPlanetsToken: status received \(String(describing: status))")
    } receiveValue: { value in
        print("fetchPlanetsToken: value received \(String(describing: value))")
    }

let fetchStarshipsToken
    = NetworkManager(session: session)
    .fetchStarships()
    .replaceError(with: Response(name: "fetchStarshipsToken failed with default response"))
    .sink { status in
        print("fetchStarshipsToken: status received \(String(describing: status))")
    } receiveValue: { value in
        print("fetchStarshipsToken: value received \(String(describing: value))")
    }

let fetchPenguinsToken
    = NetworkManager(session: session)
    .fetchPenguins()
    .sink { status in
        print("fetchPenguinsToken: status received \(String(describing: status))")
    } receiveValue: { value in
        print("fetchPenguinsToken: value received \(String(describing: value))")
    }
