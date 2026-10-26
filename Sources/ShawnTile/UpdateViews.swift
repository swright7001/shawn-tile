import SwiftUI
import TileCore

struct UpdateBanner: View {
    @ObservedObject var updates:UpdateController
    var body: some View {
        if let release = updates.available {
            HStack(alignment:.top,spacing:12) {
                Image(systemName:"arrow.down.circle.fill").font(.title2).foregroundStyle(.cyan)
                VStack(alignment:.leading,spacing:5) {
                    Text("Shawn Tile \(release.version) is available").fontWeight(.semibold)
                    Text(release.summary).font(.callout).foregroundStyle(.secondary).lineLimit(2)
                }
                Spacer(minLength:0)
                VStack {
                    Button("Update") { updates.showDetails = true }.disabled(updates.installing)
                    Button("What’s new") { updates.showDetails = true }.buttonStyle(.link)
                }
            }.padding(14).background(Color.cyan.opacity(0.09),in:RoundedRectangle(cornerRadius:12))
        } else if updates.completedNotes != nil {
            HStack {
                Image(systemName:"checkmark.circle.fill").foregroundStyle(.green)
                Text("Updated to Shawn Tile \(UpdateController.currentVersion)")
                Spacer()
                Button("What’s new") { updates.showDetails = true }
                Button("Dismiss") { updates.completedNotes = nil }
            }.padding(12).background(Color.green.opacity(0.08),in:RoundedRectangle(cornerRadius:12))
        }
    }
}
struct UpdateSettings:View {
    @ObservedObject var updates:UpdateController
    var body:some View {
        VStack(alignment:.leading,spacing:10) {
            Toggle("Automatically check for updates",isOn:$updates.automatic)
            HStack {
                Button(updates.checking ? "Checking…" : "Check for Updates") { updates.check(manual:true) }.disabled(updates.checking || updates.installing)
                if updates.checking { ProgressView().controlSize(.small) }
                if updates.available != nil { Button("Update") { updates.showDetails = true } }
            }
            if !updates.status.isEmpty { Text(updates.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
        }
    }
}
struct UpdateDetails:View {
    @ObservedObject var updates:UpdateController
    @Environment(\.dismiss) private var dismiss
    private var localSigning:Bool {
        FileManager.default.fileExists(atPath:FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Library/Application Support/Shawn Tile/Signing/identity.json").path)
    }
    var body:some View {
        VStack(alignment:.leading,spacing:16) {
            Text(updates.available.map{"Shawn Tile \($0.version)"} ?? "Shawn Tile \(UpdateController.currentVersion)").font(.title2.bold())
            if let release = updates.available {
                Text("What’s new").fontWeight(.semibold)
                ScrollView { Text(release.notes.isEmpty ? "A new version is ready." : release.notes).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:220)
                if !localSigning {
                    Text("macOS may ask you to enable Accessibility again after an update.").font(.callout).foregroundStyle(.secondary)
                }
                if updates.installing { HStack { ProgressView().controlSize(.small); Text(updates.status) } }
                else if !updates.status.isEmpty { Text(updates.status).font(.callout).foregroundStyle(.secondary).fixedSize(horizontal:false,vertical:true) }
                HStack {
                    Link("Release page",destination:release.page)
                    Spacer()
                    if updates.installing { Button("Cancel") { updates.cancel() } }
                    else {
                        Button("Later") { dismiss() }.keyboardShortcut(.cancelAction)
                        Button("Update & Restart") { updates.install() }.disabled(!updates.canInstall).keyboardShortcut(.defaultAction)
                    }
                }
            } else {
                if let notes = updates.completedNotes {
                    ScrollView { Text(notes).textSelection(.enabled).frame(maxWidth:.infinity,alignment:.leading) }.frame(height:220)
                }
                Text(updates.status.isEmpty ? "Check for the latest release and new features." : updates.status).foregroundStyle(.secondary)
                HStack {
                    Button(updates.checking ? "Checking…" : "Check for Updates") { updates.check(manual:true) }.disabled(updates.checking)
                    Spacer()
                    Button("Close") { dismiss() }.keyboardShortcut(.cancelAction)
                }
            }
        }.padding(24).frame(width:480)
        .interactiveDismissDisabled(updates.installing)
    }
}
