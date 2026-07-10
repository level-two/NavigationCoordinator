enum DemoDestination: Hashable {
    case details(number: Int)
    case legacy
    case nestedFlow
    case routingOptions
    case summary
    case sheetFlow
    case overlayFlow
    case fullScreenFlow
    case installDemoStack
    case installDuplicateDetails
    case replaceTopWithLegacy
    case replaceTopWithSummary
    case installCheckoutAndSummary
    case popToRoot
}
