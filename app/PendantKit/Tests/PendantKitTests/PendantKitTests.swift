import PendantKit
import Testing

@Test func exposesVersion() {
  #expect(!PendantKit.version.isEmpty)
}
