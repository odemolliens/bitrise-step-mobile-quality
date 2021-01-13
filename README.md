<img align="right" src="assets/icon.svg" width="150" height="150" >

# Bitrise step - Mobile app quality check & monitor

Check native mobile app quality

## Usage

Add this step using standard Workflow Editor and provide required input environment variables.

### Input

`Check Android` - yes/no - Set yes if you want check android part

`Check iOS` - yes/no - Set yes if you want check ios part

`External Build slug` - If you have your APK and/or IPA exported as artifact in another bitrise build

###### Config

`Config file path` - config_file_path - You can create a config file (see bellow example) where you can set different needed data to follow up values via your git client

`APK path` - android_apk_path - File path to APK file to get info from

`Android APK size` - android_apk_size - APK's expected size (value in MB) - *not need to set if already set into your config file*

`Android permission count` - android_permission_count - APK's expected permission count - *not need to set if already set into your config file*

`IPA path` - ios_ipa_path - To set to yes if you want check ios part

`iOS app name` - ios_app_name - iOS app name, can be found on xcode -> General -> Display Name

`iOS ipa size` - ios_ipa_size - IPA's expected size (value in MB) - *not need to set if already set into your config file*

`iOS permission` - ios_permission_count - IPA's expected permission count - *not need to set if already set into your config file*

`Alert threshold` - alert_threshold - To generate an error when Android and/or iOS app's size exceeds this threshold - *not need to set if already set into your config file*

### Outputs
`IOS_PERMISSIONS_COUNT` - new generated iOS app's permission count

`NEW_IPA_SIZE` - new generated iOS app's size

`ANDROID_PERMISSIONS_COUNT` - new generated Android app's permission count

`NEW_APK_SIZE` new generated Android app's size


#### Config file example

config.sh
```bash
android_permission_count=10
ios_permission_count=5
android_apk_size=35
ios_ipa_size=28
alert_threshold=3
```
