// swift-tools-version: 5.9
// The swift-tools-version declares the minimum version of Swift required to build this package.
//
//  Generated file. Do not edit.
//

import PackageDescription

let package = Package(
    name: "FlutterGeneratedPluginSwiftPackage",
    platforms: [
        .iOS("12.0")
    ],
    products: [
        .library(name: "FlutterGeneratedPluginSwiftPackage", type: .static, targets: ["FlutterGeneratedPluginSwiftPackage"])
    ],
    dependencies: [
        .package(name: "geolocator_apple", path: "/Users/steve/.pub-cache/hosted/pub.dev/geolocator_apple-2.3.13/darwin/geolocator_apple"),
        .package(name: "mapbox_maps_flutter", path: "/Users/steve/.pub-cache/hosted/pub.dev/mapbox_maps_flutter-2.10.0/ios/mapbox_maps_flutter"),
        .package(name: "package_info_plus", path: "/Users/steve/.pub-cache/hosted/pub.dev/package_info_plus-8.3.1/ios/package_info_plus")
    ],
    targets: [
        .target(
            name: "FlutterGeneratedPluginSwiftPackage",
            dependencies: [
                .product(name: "geolocator-apple", package: "geolocator_apple"),
                .product(name: "mapbox-maps-flutter", package: "mapbox_maps_flutter"),
                .product(name: "package-info-plus", package: "package_info_plus")
            ]
        )
    ]
)
