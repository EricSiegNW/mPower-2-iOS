//
//  StudyBurstOfflineTests.swift
//  mPower2Tests
//
//  Created by Shannon Young on 9/20/19.
//  Copyright © 2019 Sage Bionetworks. All rights reserved.
//

import XCTest
@testable import mPower2TestApp
@testable import BridgeApp
import Research
import UserNotifications

class StudyBurstOfflineTests: XCTestCase {

    override func setUp() {
        RSDFactory.shared = MP2Factory()
        StudyBurstScheduleManager.flushDefaults()
    }

    override func tearDown() {
    }
    
    func testDay1_Startup() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day1_startupState)
        
        // This scenario is to test for a new participant who has signed up but does not have
        // loaded schedules. (slow internet, race conditions, etc.) The user should be shown
        // the engagement survey and the initial state should be for Day 1 of the study burst.
        
        XCTAssertEqual(scheduleManager.dayCount, 1)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 1)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNotNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        let orderedTasks = scheduleManager.orderedTasks
        XCTAssertEqual(orderedTasks.count, 3)
        
        let todoCount = orderedTasks.reduce(0, { ($1.finishedOn != nil) ? $0 : $0 + 1})
        XCTAssertEqual(todoCount, 3)
    }
    
    func testDay2() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day2_readyToStartTasks)
        
        // This scenario is to test for a new participant who has signed up and completed all of
        // the first-day tasks, but where the launching of the app and display of the study burst
        // happens *before* the schedules are loaded, but *after* the activity manager has cached
        // them via BridgeSDK.
        scheduleManager._activityManager.buildSchedules(with: scheduleManager._participantManager)
        
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        let orderedTasks = scheduleManager.orderedTasks
        XCTAssertEqual(orderedTasks.count, 3)
        
        let todoCount = orderedTasks.reduce(0, { ($1.finishedOn != nil) ? $0 : $0 + 1})
        XCTAssertEqual(todoCount, 3)
    }
    
    func testDay2_TwoTasksFinished() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day2_twoTasksFinished)
        
        // This scenario is to test for a new participant who has signed up and completed all of
        // the first-day tasks, but where the launching of the app and display of the study burst
        // happens *before* the schedules are loaded, but *after* the activity manager has cached
        // them via BridgeSDK.
        scheduleManager._activityManager.buildSchedules(with: scheduleManager._participantManager)
        
        XCTAssertEqual(scheduleManager.dayCount, 2)
        XCTAssertTrue(scheduleManager.hasStudyBurst)
        XCTAssertFalse(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 2)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask, "scheduleManager.engagementTaskViewModel()")
        
        let orderedTasks = scheduleManager.orderedTasks
        XCTAssertEqual(orderedTasks.count, 3)
        
        let todoCount = orderedTasks.reduce(0, { ($1.finishedOn != nil) ? $0 : $0 + 1})
        XCTAssertEqual(todoCount, 1)
    }
    
    func testDay21() {
        let scheduleManager = OfflineStudyBurstScheduleManager(.day21_tasksFinished_noMissingDays)
        
        // This scenario is to test for a new participant who has signed up and completed the first
        // full study burst, but where the launching of the app and display of the study burst
        // (or not displaying in this case) happens *before* the schedules are loaded, but *after*
        // the activity manager has cached them via BridgeSDK.
        scheduleManager._activityManager.buildSchedules(with: scheduleManager._participantManager)
        
        XCTAssertNil(scheduleManager.dayCount)
        XCTAssertFalse(scheduleManager.hasStudyBurst)
        XCTAssertTrue(scheduleManager.isCompletedForToday)
        XCTAssertFalse(scheduleManager.isLastDay)
        XCTAssertEqual(scheduleManager.calculateThisDay(), 20)
        XCTAssertEqual(scheduleManager.pastSurveys.count, 0)
        
        let completionTask = scheduleManager.engagementTaskViewModel()
        XCTAssertNil(completionTask, "scheduleManager.engagementTaskViewModel()")
    }
}

class OfflineStudyBurstScheduleManager : StudyBurstScheduleManager {
    
    init(_ studySetup: StudySetup, now: Date? = nil, taskOrderTimestamp: Date? = referenceDate) {
        self._now = now ?? Date().addingNumberOfDays(-1).startOfDay().addingTimeInterval(11 * 60 * 60)
        super.init()
        
        // Default to "now" of 11:00 AM yesterday.
        var setup = studySetup
        setup.now = self._now
        setup.taskOrderTimestamp = (taskOrderTimestamp == referenceDate) ? setup.now : taskOrderTimestamp
        
        UserDefaults.standard.set(self._now.addingNumberOfDays(-1 * Int(setup.studyBurstDay)), forKey: StudyBurstScheduleManager.day1StudyBurstKey)
        
        // build the schedules.
        self._activityManager.studySetup = setup
        self._activityManager.participantManager = self._participantManager
        self._participantManager.setup(with: setup)
    }
    
    let _activityManager = ActivityManager()
    let _participantManager = ParticipantManager()
    var _now: Date
    
    var studySetup: StudySetup {
        return self._activityManager.studySetup
    }
    
    override func now() -> Date {
        return _now
    }
    
    override func today() -> Date {
        return _now
    }
    
    override var activityManager: SBBActivityManagerProtocol {
        return _activityManager
    }
    
    override var participantManager: SBBParticipantManagerProtocol {
        return _participantManager
    }
    
    var updateFinishedBlock: (() -> Void)?
    var updateFailed_error: Error?
    var update_previousActivities: [SBBScheduledActivity]?
    var update_fetchedActivities: [SBBScheduledActivity]?
    var didUpdateScheduledActivities_called: Bool = false
    var sendUpdated_schedules: [SBBScheduledActivity]?
    var sendUpdated_taskPath: RSDTaskViewModel?
    
    var finishedFetchingReportsBlock: (() -> Void)?
    
    override func updateFailed(_ error: Error) {
        updateFailed_error = error
        super.updateFailed(error)
        updateFinishedBlock?()
        updateFinishedBlock = nil
    }
    
    override func didUpdateScheduledActivities(from previousActivities: [SBBScheduledActivity]) {
        update_previousActivities = previousActivities
        update_fetchedActivities = self.scheduledActivities
        super.didUpdateScheduledActivities(from: previousActivities)
        updateFinishedBlock?()
        updateFinishedBlock = nil
    }
    
    override func didFinishFetchingReports() {
        finishedFetchingReportsBlock?()
        finishedFetchingReportsBlock = nil
    }
    
    override func sendUpdated(for schedules: [SBBScheduledActivity], taskViewModel: RSDTaskViewModel? = nil) {
        self.sendUpdated_schedules = schedules
        self.sendUpdated_taskPath = taskViewModel
        super.sendUpdated(for: schedules, taskViewModel: taskViewModel)
    }
}
