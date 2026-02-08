//
//  ShareSheet.swift
//  testen
//
//  Created by Carla Frohwein on 25.12.25.
//


import SwiftUI
import UIKit

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
