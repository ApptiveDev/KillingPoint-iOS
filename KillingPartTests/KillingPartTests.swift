//
//  KillingPartTests.swift
//  KillingPartTests
//
//  Created by 이병찬 on 2/7/26.
//

import Testing
@testable import KillingPart

struct KillingPartTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func cutHandleAdjustedControlValuesMatchAnalyticsContract() {
        #expect(AddSearchDetailTrimInteractionControl.left.rawValue == "left")
        #expect(AddSearchDetailTrimInteractionControl.right.rawValue == "right")
        #expect(AddSearchDetailTrimInteractionControl.spectrum.rawValue == "spectrum")
        #expect(AddSearchDetailTrimInteractionControl.minimap.rawValue == "minimap")
        #expect(
            AddSearchDetailTrimInteractionControl.nudgeMinusOneSecond.rawValue
                == "nudge_minus_1s"
        )
        #expect(
            AddSearchDetailTrimInteractionControl.nudgePlusOneSecond.rawValue
                == "nudge_plus_1s"
        )
        #expect(AddSearchDetailTrimInteractionControl.unknown.rawValue == "unknown")
    }

}
