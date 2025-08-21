import Foundation
#if canImport(AppKit)
import AppKit
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(SwiftUI)
import SwiftUI
#endif
#if canImport(DeveloperToolsSupport)
import DeveloperToolsSupport
#endif

#if SWIFT_PACKAGE
private let resourceBundle = Foundation.Bundle.module
#else
private class ResourceBundleClass {}
private let resourceBundle = Foundation.Bundle(for: ResourceBundleClass.self)
#endif

// MARK: - Color Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ColorResource {

}

// MARK: - Image Symbols -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension DeveloperToolsSupport.ImageResource {

    /// The "AppLogo" asset catalog image resource.
    static let appLogo = DeveloperToolsSupport.ImageResource(name: "AppLogo", bundle: resourceBundle)

    /// The "Arizona" asset catalog image resource.
    static let arizona = DeveloperToolsSupport.ImageResource(name: "Arizona", bundle: resourceBundle)

    /// The "Atlanta" asset catalog image resource.
    static let atlanta = DeveloperToolsSupport.ImageResource(name: "Atlanta", bundle: resourceBundle)

    /// The "BG" asset catalog image resource.
    static let BG = DeveloperToolsSupport.ImageResource(name: "BG", bundle: resourceBundle)

    /// The "Baltimore" asset catalog image resource.
    static let baltimore = DeveloperToolsSupport.ImageResource(name: "Baltimore", bundle: resourceBundle)

    /// The "Buffalo" asset catalog image resource.
    static let buffalo = DeveloperToolsSupport.ImageResource(name: "Buffalo", bundle: resourceBundle)

    /// The "Carolina" asset catalog image resource.
    static let carolina = DeveloperToolsSupport.ImageResource(name: "Carolina", bundle: resourceBundle)

    /// The "Chicago" asset catalog image resource.
    static let chicago = DeveloperToolsSupport.ImageResource(name: "Chicago", bundle: resourceBundle)

    /// The "Cincinnati" asset catalog image resource.
    static let cincinnati = DeveloperToolsSupport.ImageResource(name: "Cincinnati", bundle: resourceBundle)

    /// The "Cleveland" asset catalog image resource.
    static let cleveland = DeveloperToolsSupport.ImageResource(name: "Cleveland", bundle: resourceBundle)

    /// The "Crease" asset catalog image resource.
    static let crease = DeveloperToolsSupport.ImageResource(name: "Crease", bundle: resourceBundle)

    /// The "Dallas" asset catalog image resource.
    static let dallas = DeveloperToolsSupport.ImageResource(name: "Dallas", bundle: resourceBundle)

    /// The "Denver" asset catalog image resource.
    static let denver = DeveloperToolsSupport.ImageResource(name: "Denver", bundle: resourceBundle)

    /// The "Detroit" asset catalog image resource.
    static let detroit = DeveloperToolsSupport.ImageResource(name: "Detroit", bundle: resourceBundle)

    /// The "GreenBay" asset catalog image resource.
    static let greenBay = DeveloperToolsSupport.ImageResource(name: "GreenBay", bundle: resourceBundle)

    /// The "Houston" asset catalog image resource.
    static let houston = DeveloperToolsSupport.ImageResource(name: "Houston", bundle: resourceBundle)

    /// The "Indianapolis" asset catalog image resource.
    static let indianapolis = DeveloperToolsSupport.ImageResource(name: "Indianapolis", bundle: resourceBundle)

    /// The "Jacksonville" asset catalog image resource.
    static let jacksonville = DeveloperToolsSupport.ImageResource(name: "Jacksonville", bundle: resourceBundle)

    /// The "KansasCity" asset catalog image resource.
    static let kansasCity = DeveloperToolsSupport.ImageResource(name: "KansasCity", bundle: resourceBundle)

    /// The "LAA" asset catalog image resource.
    static let LAA = DeveloperToolsSupport.ImageResource(name: "LAA", bundle: resourceBundle)

    /// The "LAN" asset catalog image resource.
    static let LAN = DeveloperToolsSupport.ImageResource(name: "LAN", bundle: resourceBundle)

    /// The "Laces" asset catalog image resource.
    static let laces = DeveloperToolsSupport.ImageResource(name: "Laces", bundle: resourceBundle)

    /// The "LasVegas" asset catalog image resource.
    static let lasVegas = DeveloperToolsSupport.ImageResource(name: "LasVegas", bundle: resourceBundle)

    /// The "Miami" asset catalog image resource.
    static let miami = DeveloperToolsSupport.ImageResource(name: "Miami", bundle: resourceBundle)

    /// The "Minnesota" asset catalog image resource.
    static let minnesota = DeveloperToolsSupport.ImageResource(name: "Minnesota", bundle: resourceBundle)

    /// The "NYA" asset catalog image resource.
    static let NYA = DeveloperToolsSupport.ImageResource(name: "NYA", bundle: resourceBundle)

    /// The "NYN" asset catalog image resource.
    static let NYN = DeveloperToolsSupport.ImageResource(name: "NYN", bundle: resourceBundle)

    /// The "NewEngland" asset catalog image resource.
    static let newEngland = DeveloperToolsSupport.ImageResource(name: "NewEngland", bundle: resourceBundle)

    /// The "NewOrleans" asset catalog image resource.
    static let newOrleans = DeveloperToolsSupport.ImageResource(name: "NewOrleans", bundle: resourceBundle)

    /// The "PSF" asset catalog image resource.
    static let PSF = DeveloperToolsSupport.ImageResource(name: "PSF", bundle: resourceBundle)

    /// The "Philadelphia" asset catalog image resource.
    static let philadelphia = DeveloperToolsSupport.ImageResource(name: "Philadelphia", bundle: resourceBundle)

    /// The "Pittsburgh" asset catalog image resource.
    static let pittsburgh = DeveloperToolsSupport.ImageResource(name: "Pittsburgh", bundle: resourceBundle)

    /// The "SanFrancisco" asset catalog image resource.
    static let sanFrancisco = DeveloperToolsSupport.ImageResource(name: "SanFrancisco", bundle: resourceBundle)

    /// The "Seattle" asset catalog image resource.
    static let seattle = DeveloperToolsSupport.ImageResource(name: "Seattle", bundle: resourceBundle)

    /// The "Stripes" asset catalog image resource.
    static let stripes = DeveloperToolsSupport.ImageResource(name: "Stripes", bundle: resourceBundle)

    /// The "TampaBay" asset catalog image resource.
    static let tampaBay = DeveloperToolsSupport.ImageResource(name: "TampaBay", bundle: resourceBundle)

    /// The "Tennessee" asset catalog image resource.
    static let tennessee = DeveloperToolsSupport.ImageResource(name: "Tennessee", bundle: resourceBundle)

    /// The "Washington" asset catalog image resource.
    static let washington = DeveloperToolsSupport.ImageResource(name: "Washington", bundle: resourceBundle)

    /// The "XXVI" asset catalog image resource.
    static let XXVI = DeveloperToolsSupport.ImageResource(name: "XXVI", bundle: resourceBundle)

    /// The "championshiplogo" asset catalog image resource.
    static let championshiplogo = DeveloperToolsSupport.ImageResource(name: "championshiplogo", bundle: resourceBundle)

    /// The "conferencechampionship1_logo" asset catalog image resource.
    static let conferencechampionship1Logo = DeveloperToolsSupport.ImageResource(name: "conferencechampionship1_logo", bundle: resourceBundle)

    /// The "conferencechampionship2_logo" asset catalog image resource.
    static let conferencechampionship2Logo = DeveloperToolsSupport.ImageResource(name: "conferencechampionship2_logo", bundle: resourceBundle)

    /// The "conferencelogo1" asset catalog image resource.
    static let conferencelogo1 = DeveloperToolsSupport.ImageResource(name: "conferencelogo1", bundle: resourceBundle)

    /// The "conferencelogo2" asset catalog image resource.
    static let conferencelogo2 = DeveloperToolsSupport.ImageResource(name: "conferencelogo2", bundle: resourceBundle)

    /// The "divisionalround" asset catalog image resource.
    static let divisionalround = DeveloperToolsSupport.ImageResource(name: "divisionalround", bundle: resourceBundle)

    /// The "gradient-background" asset catalog image resource.
    static let gradientBackground = DeveloperToolsSupport.ImageResource(name: "gradient-background", bundle: resourceBundle)

    /// The "leaguelogo" asset catalog image resource.
    static let leaguelogo = DeveloperToolsSupport.ImageResource(name: "leaguelogo", bundle: resourceBundle)

    /// The "wildcardround" asset catalog image resource.
    static let wildcardround = DeveloperToolsSupport.ImageResource(name: "wildcardround", bundle: resourceBundle)

}

// MARK: - Color Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSColor {

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

}
#endif

// MARK: - Image Symbol Extensions -

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    /// The "AppLogo" asset catalog image.
    static var appLogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .appLogo)
#else
        .init()
#endif
    }

    /// The "Arizona" asset catalog image.
    static var arizona: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .arizona)
#else
        .init()
#endif
    }

    /// The "Atlanta" asset catalog image.
    static var atlanta: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .atlanta)
#else
        .init()
#endif
    }

    /// The "BG" asset catalog image.
    static var BG: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .BG)
#else
        .init()
#endif
    }

    /// The "Baltimore" asset catalog image.
    static var baltimore: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .baltimore)
#else
        .init()
#endif
    }

    /// The "Buffalo" asset catalog image.
    static var buffalo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .buffalo)
#else
        .init()
#endif
    }

    /// The "Carolina" asset catalog image.
    static var carolina: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .carolina)
#else
        .init()
#endif
    }

    /// The "Chicago" asset catalog image.
    static var chicago: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .chicago)
#else
        .init()
#endif
    }

    /// The "Cincinnati" asset catalog image.
    static var cincinnati: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .cincinnati)
#else
        .init()
#endif
    }

    /// The "Cleveland" asset catalog image.
    static var cleveland: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .cleveland)
#else
        .init()
#endif
    }

    /// The "Crease" asset catalog image.
    static var crease: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .crease)
#else
        .init()
#endif
    }

    /// The "Dallas" asset catalog image.
    static var dallas: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .dallas)
#else
        .init()
#endif
    }

    /// The "Denver" asset catalog image.
    static var denver: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .denver)
#else
        .init()
#endif
    }

    /// The "Detroit" asset catalog image.
    static var detroit: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .detroit)
#else
        .init()
#endif
    }

    /// The "GreenBay" asset catalog image.
    static var greenBay: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .greenBay)
#else
        .init()
#endif
    }

    /// The "Houston" asset catalog image.
    static var houston: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .houston)
#else
        .init()
#endif
    }

    /// The "Indianapolis" asset catalog image.
    static var indianapolis: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .indianapolis)
#else
        .init()
#endif
    }

    /// The "Jacksonville" asset catalog image.
    static var jacksonville: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .jacksonville)
#else
        .init()
#endif
    }

    /// The "KansasCity" asset catalog image.
    static var kansasCity: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .kansasCity)
#else
        .init()
#endif
    }

    /// The "LAA" asset catalog image.
    static var LAA: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .LAA)
#else
        .init()
#endif
    }

    /// The "LAN" asset catalog image.
    static var LAN: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .LAN)
#else
        .init()
#endif
    }

    /// The "Laces" asset catalog image.
    static var laces: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .laces)
#else
        .init()
#endif
    }

    /// The "LasVegas" asset catalog image.
    static var lasVegas: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .lasVegas)
#else
        .init()
#endif
    }

    /// The "Miami" asset catalog image.
    static var miami: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .miami)
#else
        .init()
#endif
    }

    /// The "Minnesota" asset catalog image.
    static var minnesota: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .minnesota)
#else
        .init()
#endif
    }

    /// The "NYA" asset catalog image.
    static var NYA: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .NYA)
#else
        .init()
#endif
    }

    /// The "NYN" asset catalog image.
    static var NYN: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .NYN)
#else
        .init()
#endif
    }

    /// The "NewEngland" asset catalog image.
    static var newEngland: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .newEngland)
#else
        .init()
#endif
    }

    /// The "NewOrleans" asset catalog image.
    static var newOrleans: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .newOrleans)
#else
        .init()
#endif
    }

    /// The "PSF" asset catalog image.
    static var PSF: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .PSF)
#else
        .init()
#endif
    }

    /// The "Philadelphia" asset catalog image.
    static var philadelphia: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .philadelphia)
#else
        .init()
#endif
    }

    /// The "Pittsburgh" asset catalog image.
    static var pittsburgh: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .pittsburgh)
#else
        .init()
#endif
    }

    /// The "SanFrancisco" asset catalog image.
    static var sanFrancisco: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .sanFrancisco)
#else
        .init()
#endif
    }

    /// The "Seattle" asset catalog image.
    static var seattle: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .seattle)
#else
        .init()
#endif
    }

    /// The "Stripes" asset catalog image.
    static var stripes: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .stripes)
#else
        .init()
#endif
    }

    /// The "TampaBay" asset catalog image.
    static var tampaBay: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tampaBay)
#else
        .init()
#endif
    }

    /// The "Tennessee" asset catalog image.
    static var tennessee: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .tennessee)
#else
        .init()
#endif
    }

    /// The "Washington" asset catalog image.
    static var washington: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .washington)
#else
        .init()
#endif
    }

    /// The "XXVI" asset catalog image.
    static var XXVI: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .XXVI)
#else
        .init()
#endif
    }

    /// The "championshiplogo" asset catalog image.
    static var championshiplogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .championshiplogo)
#else
        .init()
#endif
    }

    /// The "conferencechampionship1_logo" asset catalog image.
    static var conferencechampionship1Logo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .conferencechampionship1Logo)
#else
        .init()
#endif
    }

    /// The "conferencechampionship2_logo" asset catalog image.
    static var conferencechampionship2Logo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .conferencechampionship2Logo)
#else
        .init()
#endif
    }

    /// The "conferencelogo1" asset catalog image.
    static var conferencelogo1: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .conferencelogo1)
#else
        .init()
#endif
    }

    /// The "conferencelogo2" asset catalog image.
    static var conferencelogo2: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .conferencelogo2)
#else
        .init()
#endif
    }

    /// The "divisionalround" asset catalog image.
    static var divisionalround: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .divisionalround)
#else
        .init()
#endif
    }

    /// The "gradient-background" asset catalog image.
    static var gradientBackground: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .gradientBackground)
#else
        .init()
#endif
    }

    /// The "leaguelogo" asset catalog image.
    static var leaguelogo: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .leaguelogo)
#else
        .init()
#endif
    }

    /// The "wildcardround" asset catalog image.
    static var wildcardround: AppKit.NSImage {
#if !targetEnvironment(macCatalyst)
        .init(resource: .wildcardround)
#else
        .init()
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    /// The "AppLogo" asset catalog image.
    static var appLogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .appLogo)
#else
        .init()
#endif
    }

    /// The "Arizona" asset catalog image.
    static var arizona: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .arizona)
#else
        .init()
#endif
    }

    /// The "Atlanta" asset catalog image.
    static var atlanta: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .atlanta)
#else
        .init()
#endif
    }

    /// The "BG" asset catalog image.
    static var BG: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .BG)
#else
        .init()
#endif
    }

    /// The "Baltimore" asset catalog image.
    static var baltimore: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .baltimore)
#else
        .init()
#endif
    }

    /// The "Buffalo" asset catalog image.
    static var buffalo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .buffalo)
#else
        .init()
#endif
    }

    /// The "Carolina" asset catalog image.
    static var carolina: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .carolina)
#else
        .init()
#endif
    }

    /// The "Chicago" asset catalog image.
    static var chicago: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .chicago)
#else
        .init()
#endif
    }

    /// The "Cincinnati" asset catalog image.
    static var cincinnati: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .cincinnati)
#else
        .init()
#endif
    }

    /// The "Cleveland" asset catalog image.
    static var cleveland: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .cleveland)
#else
        .init()
#endif
    }

    /// The "Crease" asset catalog image.
    static var crease: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .crease)
#else
        .init()
#endif
    }

    /// The "Dallas" asset catalog image.
    static var dallas: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .dallas)
#else
        .init()
#endif
    }

    /// The "Denver" asset catalog image.
    static var denver: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .denver)
#else
        .init()
#endif
    }

    /// The "Detroit" asset catalog image.
    static var detroit: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .detroit)
#else
        .init()
#endif
    }

    /// The "GreenBay" asset catalog image.
    static var greenBay: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .greenBay)
#else
        .init()
#endif
    }

    /// The "Houston" asset catalog image.
    static var houston: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .houston)
#else
        .init()
#endif
    }

    /// The "Indianapolis" asset catalog image.
    static var indianapolis: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .indianapolis)
#else
        .init()
#endif
    }

    /// The "Jacksonville" asset catalog image.
    static var jacksonville: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .jacksonville)
#else
        .init()
#endif
    }

    /// The "KansasCity" asset catalog image.
    static var kansasCity: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .kansasCity)
#else
        .init()
#endif
    }

    /// The "LAA" asset catalog image.
    static var LAA: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .LAA)
#else
        .init()
#endif
    }

    /// The "LAN" asset catalog image.
    static var LAN: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .LAN)
#else
        .init()
#endif
    }

    /// The "Laces" asset catalog image.
    static var laces: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .laces)
#else
        .init()
#endif
    }

    /// The "LasVegas" asset catalog image.
    static var lasVegas: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .lasVegas)
#else
        .init()
#endif
    }

    /// The "Miami" asset catalog image.
    static var miami: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .miami)
#else
        .init()
#endif
    }

    /// The "Minnesota" asset catalog image.
    static var minnesota: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .minnesota)
#else
        .init()
#endif
    }

    /// The "NYA" asset catalog image.
    static var NYA: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .NYA)
#else
        .init()
#endif
    }

    /// The "NYN" asset catalog image.
    static var NYN: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .NYN)
#else
        .init()
#endif
    }

    /// The "NewEngland" asset catalog image.
    static var newEngland: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .newEngland)
#else
        .init()
#endif
    }

    /// The "NewOrleans" asset catalog image.
    static var newOrleans: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .newOrleans)
#else
        .init()
#endif
    }

    /// The "PSF" asset catalog image.
    static var PSF: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .PSF)
#else
        .init()
#endif
    }

    /// The "Philadelphia" asset catalog image.
    static var philadelphia: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .philadelphia)
#else
        .init()
#endif
    }

    /// The "Pittsburgh" asset catalog image.
    static var pittsburgh: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .pittsburgh)
#else
        .init()
#endif
    }

    /// The "SanFrancisco" asset catalog image.
    static var sanFrancisco: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .sanFrancisco)
#else
        .init()
#endif
    }

    /// The "Seattle" asset catalog image.
    static var seattle: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .seattle)
#else
        .init()
#endif
    }

    /// The "Stripes" asset catalog image.
    static var stripes: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .stripes)
#else
        .init()
#endif
    }

    /// The "TampaBay" asset catalog image.
    static var tampaBay: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .tampaBay)
#else
        .init()
#endif
    }

    /// The "Tennessee" asset catalog image.
    static var tennessee: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .tennessee)
#else
        .init()
#endif
    }

    /// The "Washington" asset catalog image.
    static var washington: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .washington)
#else
        .init()
#endif
    }

    /// The "XXVI" asset catalog image.
    static var XXVI: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .XXVI)
#else
        .init()
#endif
    }

    /// The "championshiplogo" asset catalog image.
    static var championshiplogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .championshiplogo)
#else
        .init()
#endif
    }

    /// The "conferencechampionship1_logo" asset catalog image.
    static var conferencechampionship1Logo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .conferencechampionship1Logo)
#else
        .init()
#endif
    }

    /// The "conferencechampionship2_logo" asset catalog image.
    static var conferencechampionship2Logo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .conferencechampionship2Logo)
#else
        .init()
#endif
    }

    /// The "conferencelogo1" asset catalog image.
    static var conferencelogo1: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .conferencelogo1)
#else
        .init()
#endif
    }

    /// The "conferencelogo2" asset catalog image.
    static var conferencelogo2: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .conferencelogo2)
#else
        .init()
#endif
    }

    /// The "divisionalround" asset catalog image.
    static var divisionalround: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .divisionalround)
#else
        .init()
#endif
    }

    /// The "gradient-background" asset catalog image.
    static var gradientBackground: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .gradientBackground)
#else
        .init()
#endif
    }

    /// The "leaguelogo" asset catalog image.
    static var leaguelogo: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .leaguelogo)
#else
        .init()
#endif
    }

    /// The "wildcardround" asset catalog image.
    static var wildcardround: UIKit.UIImage {
#if !os(watchOS)
        .init(resource: .wildcardround)
#else
        .init()
#endif
    }

}
#endif

// MARK: - Thinnable Asset Support -

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ColorResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if AppKit.NSColor(named: NSColor.Name(thinnableName), bundle: bundle) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIColor(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIColor {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(SwiftUI)
@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
extension SwiftUI.ShapeStyle where Self == SwiftUI.Color {

    private init?(thinnableResource: DeveloperToolsSupport.ColorResource?) {
        if let resource = thinnableResource {
            self.init(resource)
        } else {
            return nil
        }
    }

}
#endif

@available(iOS 17.0, macOS 14.0, tvOS 17.0, watchOS 10.0, *)
@available(watchOS, unavailable)
extension DeveloperToolsSupport.ImageResource {

    private init?(thinnableName: Swift.String, bundle: Foundation.Bundle) {
#if canImport(AppKit) && os(macOS)
        if bundle.image(forResource: NSImage.Name(thinnableName)) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#elseif canImport(UIKit) && !os(watchOS)
        if UIKit.UIImage(named: thinnableName, in: bundle, compatibleWith: nil) != nil {
            self.init(name: thinnableName, bundle: bundle)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}

#if canImport(AppKit)
@available(macOS 14.0, *)
@available(macCatalyst, unavailable)
extension AppKit.NSImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !targetEnvironment(macCatalyst)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

#if canImport(UIKit)
@available(iOS 17.0, tvOS 17.0, *)
@available(watchOS, unavailable)
extension UIKit.UIImage {

    private convenience init?(thinnableResource: DeveloperToolsSupport.ImageResource?) {
#if !os(watchOS)
        if let resource = thinnableResource {
            self.init(resource: resource)
        } else {
            return nil
        }
#else
        return nil
#endif
    }

}
#endif

