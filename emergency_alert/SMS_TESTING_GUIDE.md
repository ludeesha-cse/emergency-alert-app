# Emergency SMS Testing Guide

## Overview

This guide provides comprehensive testing scenarios for the automatic SMS functionality in the Emergency Alert app. The implementation uses a custom platform channel to send SMS messages automatically without user intervention.

## Prerequisites

### Before Testing

1. **Physical Android Device**: SMS functionality requires a real device with cellular capability
2. **SIM Card**: Device must have an active SIM card for SMS sending
3. **Test Phone Numbers**: Have 2-3 test phone numbers available (can be other devices you control)
4. **SMS Permissions**: Ensure SMS permissions are granted to the app
5. **Emergency Contacts**: Configure at least one emergency contact in the app

### Setup Steps

1. Install the app on a physical Android device
2. Grant all required permissions (SMS, Location, Sensors, etc.)
3. Add test emergency contacts through the Contacts screen
4. Enable fall detection in Settings

## Test Scenarios

### 1. Platform Channel SMS Testing

#### Test 1.1: Direct SMS Sending

**Objective**: Verify platform channel SMS sending works correctly

**Steps**:

1. Open the app and navigate to Contacts screen
2. Add a test emergency contact
3. Tap the three-dot menu on the contact
4. Select "Test SMS"
5. Confirm sending in the dialog

**Expected Result**:

- SMS is sent automatically without opening messaging app
- Success message appears in the app
- Recipient receives the test message immediately
- Message content includes "This is a test message from [User]'s Emergency Alert app"

**Alternative Result (Fallback)**:

- If platform channel fails, messaging app opens with pre-filled text
- User can manually send the message

#### Test 1.2: Multiple Recipients

**Objective**: Test batch SMS sending to multiple contacts

**Steps**:

1. Add 2-3 emergency contacts
2. Enable all contacts
3. Use test message functionality on different contacts
4. Or trigger an emergency scenario (see Emergency Flow Testing)

**Expected Result**:

- All enabled contacts receive SMS simultaneously
- No manual intervention required
- All contacts receive identical emergency message content

### 2. Emergency Flow Testing

#### Test 2.1: Fall Detection SMS

**Objective**: Verify automatic SMS during fall detection

**Steps**:

1. Ensure fall detection is enabled in Settings
2. Add at least one emergency contact
3. Simulate a fall by dropping the device from a reasonable height (be careful!)
4. Alternative: Shake the device vigorously to simulate impact

**Expected Result**:

- Fall/impact is detected by sensors
- Emergency countdown starts (30 seconds by default)
- Audio alarm, vibration, and flashlight activate
- After countdown, SMS is sent automatically to all enabled contacts
- SMS includes: Emergency type, timestamp, location (if available), app signature

**Emergency SMS Content Example**:

```
EMERGENCY ALERT
Type: Fall Detected
Time: 2025-05-25 14:30:15
Location: [GPS coordinates or address if available]
Sent via Emergency Alert App
```

#### Test 2.2: Manual Emergency Button

**Objective**: Test manual emergency trigger

**Steps**:

1. Navigate to Home screen
2. Look for emergency/panic button
3. Press the emergency button
4. Observe countdown and automatic SMS sending

**Expected Result**:

- Manual emergency is triggered
- Same emergency response as fall detection
- SMS sent automatically after countdown

#### Test 2.3: Emergency Cancellation

**Objective**: Test emergency cancellation and cancellation SMS

**Steps**:

1. Trigger an emergency (fall detection or manual)
2. During the countdown period, cancel the emergency
3. Observe that no emergency SMS is sent

**Alternative**:

1. Allow emergency to proceed and SMS to be sent
2. Then cancel the emergency
3. Verify cancellation SMS is sent

**Expected Result for Early Cancellation**:

- Emergency is cancelled
- No emergency SMS sent
- Emergency responses (audio, vibration, flashlight) stop

**Expected Result for Post-SMS Cancellation**:

- Cancellation SMS sent to all contacts
- Message indicates the emergency has been cancelled and person is safe

### 3. Error Handling & Fallback Testing

#### Test 3.1: SMS Permission Denied

**Objective**: Test behavior when SMS permissions are not granted

**Steps**:

1. Revoke SMS permissions for the app (Android Settings > Apps > Emergency Alert > Permissions)
2. Trigger emergency or test SMS
3. Observe fallback behavior

**Expected Result**:

- App detects missing SMS permission
- Falls back to URL launcher method (opens messaging app)
- User sees messaging app with pre-filled text
- Error logged in app (visible in debug mode)

#### Test 3.2: No Network/Cellular Signal

**Objective**: Test behavior with poor cellular connectivity

**Steps**:

1. Move to an area with poor cellular signal or enable airplane mode briefly
2. Trigger emergency SMS
3. Restore connectivity

**Expected Result**:

- Platform channel attempts SMS sending
- Android handles SMS queuing automatically
- SMS may be delayed but eventually delivered when signal improves

#### Test 3.3: Invalid Phone Numbers

**Objective**: Test handling of invalid contact phone numbers

**Steps**:

1. Add an emergency contact with invalid phone number (e.g., "123")
2. Add a valid contact as well
3. Trigger emergency SMS

**Expected Result**:

- Valid contacts receive SMS successfully
- Invalid contacts fail gracefully
- App continues operation
- Error logged for invalid numbers

### 4. Platform Channel Integration Testing

#### Test 4.1: Method Channel Communication

**Objective**: Verify Flutter-Android communication

**Steps**:

1. Enable debug logging
2. Trigger SMS sending
3. Check debug logs for platform channel communication

**Expected Debug Output**:

- Method channel call to "sendSMS"
- Parameters passed correctly (message, phone numbers)
- Success/failure response from Android
- Fallback activation if platform channel fails

#### Test 4.2: Long Message Handling

**Objective**: Test multipart SMS for long messages

**Steps**:

1. Trigger emergency with location information (creates longer message)
2. Verify message is sent correctly

**Expected Result**:

- Long messages are automatically split into multiple SMS parts
- All parts are delivered to recipients
- Content remains intact when reassembled

### 5. Real-World Scenario Testing

#### Test 5.1: Complete Emergency Scenario

**Objective**: Full end-to-end emergency response test

**Setup**:

- Real emergency contacts (family/friends who can confirm receipt)
- Actual emergency scenario simulation

**Steps**:

1. Inform contacts this is a test
2. Simulate fall or trigger manual emergency
3. Allow complete emergency flow to execute
4. Confirm with contacts they received SMS
5. Test cancellation SMS if needed

**Success Criteria**:

- Contacts receive emergency SMS within expected timeframe
- SMS content is clear and informative
- Location information is included if available
- Cancellation SMS works if tested

#### Test 5.2: Background Operation

**Objective**: Test SMS functionality when app is in background

**Steps**:

1. Start the app and enable background monitoring
2. Put app in background or close it
3. Simulate fall detection (carefully drop device)
4. Verify emergency response works from background

**Expected Result**:

- Background service detects emergency
- SMS sent automatically even with app in background
- All emergency responses activate

## Troubleshooting

### Common Issues and Solutions

1. **SMS Not Sending**:

   - Check SMS permissions are granted
   - Verify cellular connection
   - Check if SIM card is properly inserted
   - Try test SMS first before emergency scenarios

2. **Platform Channel Errors**:

   - Should automatically fall back to URL launcher
   - Check debug logs for specific error messages
   - Restart app if persistent issues

3. **Emergency Not Triggering**:

   - Verify sensor permissions are granted
   - Check if fall/impact detection is enabled in settings
   - Try different movement patterns for detection

4. **Multiple SMS Received**:
   - Normal for long messages (multipart SMS)
   - Check if emergency was triggered multiple times

## Documentation

### Debug Information

- All SMS operations are logged with timestamps
- Platform channel communication is logged
- Error messages include specific failure reasons
- Success/failure status returned for each operation

### Performance Metrics

- SMS sending typically completes within 2-5 seconds
- Platform channel communication is nearly instantaneous
- Fallback activation adds minimal delay

## Test Results Template

| Test Scenario          | Expected Result          | Actual Result | Status | Notes |
| ---------------------- | ------------------------ | ------------- | ------ | ----- |
| Direct SMS Sending     | SMS sent automatically   |               |        |       |
| Multiple Recipients    | All contacts receive SMS |               |        |       |
| Fall Detection SMS     | SMS sent after fall      |               |        |       |
| Emergency Cancellation | Cancellation SMS sent    |               |        |       |
| Permission Denied      | Fallback to URL launcher |               |        |       |
| Invalid Phone Numbers  | Graceful error handling  |               |        |       |
| Long Message Handling  | Multipart SMS works      |               |        |       |
| Background Operation   | SMS sent from background |               |        |       |

## Next Steps After Testing

1. **Document Results**: Record all test outcomes
2. **Report Issues**: Log any failures or unexpected behaviors
3. **Performance Tuning**: Adjust timeouts or thresholds if needed
4. **User Training**: Educate users on proper setup and testing
5. **Production Deployment**: Deploy to production after successful testing
