<img align="right" src="assets/icon.svg">
# Bitrise step - Mobile app quality check & monitor

Check native mobbile app quality

## Usage

Add this step using standard Workflow Editor and provide required input environment variables.

### Input

`Check Android` - yes/no - To set to yes if you want check android part
`Check iOS` - yes/no - To set to yes if you want check ios part

`External Build slug` - Build slug if you have your APK and/or IPA exported as artifact in another bitrise build

###### Config

`Config file path` - config_file_path - You can create a config file (see bellow example) where you can set different needed data to follow up values via your git client

`APK path` - android_apk_path - To set to yes if you want check ios part
`Android APK size` - android_apk_size - To set to yes if you want check ios part
`Android permission count` - android_permission_count - To set to yes if you want check ios part

`IPA path` - ios_ipa_path - To set to yes if you want check ios part
`iOS app name` - ios_app_name - To set to yes if you want check ios part
`iOS ipa size` - ios_ipa_size - To set to yes if you want check ios part
`iOS permission` - ios_permission_count - To set to yes if you want check ios part

`Alert threshold` - alert_threshold - To set to yes if you want check ios part

### Outputs
`$IOS_PERMISSIONS_COUNT` - new generated iOS app's permission count

`$NEW_IPA_SIZE` - new generated iOS app's size

`$ANDROID_PERMISSIONS_COUNT` new generated Android app's permission count

`$NEW_APK_SIZE` new generated Android app's size


#### Config file example

config.sh
```bash
android_permission_count=10
ios_permission_count=5
android_apk_size=35
ios_ipa_size=28
alert_threshold=3
```
