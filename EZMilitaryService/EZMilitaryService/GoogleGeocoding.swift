//
//  GoogleGeocoding.swift
//  EZMilitaryService
//
//  Created by Allen Su on 5/29/25.
//

import Foundation

struct GeocodeResponse: Codable {
    let results: [GeocodeResult]
    let status: String
}

struct GeocodeResult: Codable {
    let addressComponents: [AddressComponent]
    
    enum CodingKeys: String, CodingKey {
        case addressComponents = "address_components"
    }
}

struct AddressComponent: Codable {
    let longName: String
    let shortName: String
    let types: [String]
    
    enum CodingKeys: String, CodingKey {
        case longName = "long_name"
        case shortName = "short_name"
        case types
    }
}

enum GeocodingError: Error {
    case invalidURL
    case noVillageFound
    case networkError(Error)
    case invalidResponse
    case decodingError(Error)
}

class GoogleGeocoding {
    private let apiKey = Config.googleApiKey
    
    func getVillageName(from address: String) async throws -> String {
        let encodedAddress = address.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? address
        guard let url = URL(string: "https://maps.googleapis.com/maps/api/geocode/json?address=\(encodedAddress)&key=\(apiKey)") else {
            throw GeocodingError.invalidURL
        }
        
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw GeocodingError.invalidResponse
            }
            
            let decoder = JSONDecoder()
            let geocodeResponse = try decoder.decode(GeocodeResponse.self, from: data)
            
            guard let village = geocodeResponse.results.first?
                    .addressComponents
                    .first(where: { $0.types.contains("administrative_area_level_3") })?
                    .longName else {
                throw GeocodingError.noVillageFound
            }
            
            return village
            
        } catch let error as DecodingError {
            throw GeocodingError.decodingError(error)
        } catch {
            throw GeocodingError.networkError(error)
        }
    }
}
