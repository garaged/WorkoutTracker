import SwiftUI
import StoreKit

struct SupportTipJarView: View {

    @StateObject private var store = TipJarStore(productIDs: [
        // Must match App Store Connect product IDs
        "tip_small",
        "tip_medium",
        "tip_large"
    ])

    @State private var showThanks = false

    var body: some View {
        List {
            Section {
                Text("WorkoutTracker is free and open-source. If you want to support ongoing development, you can leave a tip here. Nothing is locked behind payment.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            Section("Tip Jar") {
                if store.isLoading {
                    ProgressView()
                } else if store.products.isEmpty {
                    Button("Reload tip options") {
                        Task { await store.loadProducts() }
                    }
                } else {
                    ForEach(store.products, id: \.id) { product in
                        Button {
                            Task {
                                let ok = await store.purchase(product)
                                if ok { showThanks = true }
                            }
                        } label: {
                            HStack {
                                Text(product.displayName)
                                Spacer()
                                Text(product.displayPrice)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if let msg = store.lastErrorMessage {
                    Text(msg)
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
        }
        .readableWidth()
        .navigationTitle("Support")
        .task { await store.loadProducts() }
        .alert("Thank you!", isPresented: $showThanks) {
            Button("Done", role: .cancel) {}
        } message: {
            Text("Your support helps keep the project healthy.")
        }
    }
}
