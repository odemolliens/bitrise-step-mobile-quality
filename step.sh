#!/bin/bash
set -ex

echo "---- CONFIG ----"
if [ -n "$config_file_path" ]; then
    echo "get config from the config file"
    source build_config/released_app_infos.sh
else
    echo "get config from bitrise input"
fi;

if [[ ${check_android} == "yes" && ${android_permission_count} == "" && ${android_apk_size} == "" ]]; then
    echo "Error: Config keys are not set preperly"
    echo "Error: You configured to check android part but android_permission_count and android_apk_size are not set "
    exit 1
fi

if [[ ${check_ios} == "yes" && ${ios_permission_count} == "" && ${ios_ipa_size} == ""  ]]; then
    echo "Error: Config keys are not set preperly"
    echo "Error: You configured to check ios part but ios_permission_count and ios_permission_count are not set "
    exit 1
fi

if [[ ${alert_threshold} == ""  ]]; then
    alert_threshold="5"
fi

# install jq to parse json content
brew install jq || true
# install gsed to remove text
brew install gnu-sed || true

# get current app infos
source build_config/released_app_infos.sh

# dl artifacts list
if [[ ${outside_build_slug} != ""  ]]; then
    BUILD_ARTIFACTS=$(curl -X GET "https://api.bitrise.io/v0.1/apps/${BITRISE_APP_SLUG}/builds/${outside_build_slug}/artifacts" -H "accept: application/json" -H "Authorization: ${BITRISE_TOKEN}")
fi

if [[ ${check_android} == "yes" ]]; then
    if [[ ${outside_build_slug} != ""  ]]; then
        # we will download the artifact and decompile
        # dl artifact specific for android
        ANDROID_DATA_FROM_ARTIFACTS=$(echo $BUILD_ARTIFACTS | jq '.data[] | select (.artifact_type == "android-apk")')

        if [[ ${ANDROID_DATA_FROM_ARTIFACTS} == "" ]]; then
            echo "ERROR: Didn't find any apk file in your main build with slug: $MAIN_BUILD_SLUG"
            exit 1
        fi

        ANDROID_DATA_SLUG=$(echo $ANDROID_DATA_FROM_ARTIFACTS | jq '.slug' | sed 's/"//g')
        ANDROID_NEW_APP_SIZE=$(echo $ANDROID_DATA_FROM_ARTIFACTS | jq '.file_size_bytes' | sed 's/"//g')
        ANDROID_NEW_APP_SIZE_MB=$(echo "$ANDROID_NEW_APP_SIZE / 1024^2" | bc)
        ANDROID_APK_URL=$(curl -X GET "https://api.bitrise.io/v0.1/apps/${BITRISE_APP_SLUG}/builds/${outside_build_slug}/artifacts/${ANDROID_DATA_SLUG}" -H "accept: application/json" -H "Authorization: ${BITRISE_TOKEN}" | jq '.data.expiring_download_url' | sed 's/"//g')

        # download android apk
        curl -X GET ${ANDROID_APK_URL} -o android.apk

        # tool to decompile apk
        brew install apktool || true

        # decompile the apk
        apktool d android.apk -o apk_decompiled
    else
        # we will decompile the apk from android_apk_path
        if [[ ${android_apk_path} == "" ]]; then
            echo "ERROR: Didn't find any apk file, please check android apk path (android_apk_path=$android_apk_path)"
            exit 1
        fi

        # tool to decompile apk
        brew install apktool || true

        # decompile the apk
        apktool d $android_apk_path -o apk_decompiled
    fi

    # PERMISSION CHECK - count permissions which are into current build's manifest
    CURRENT_ANDROID_BUILDS_PERMISSIONS_COUNT=$(grep -o -i "<uses-permission" apk_decompiled/AndroidManifest.xml | wc -l)
    if [ $CURRENT_ANDROID_BUILDS_PERMISSIONS_COUNT -gt $android_permission_count ]; then
        ANDROID_PERMISSIONS_COUNT=$CURRENT_ANDROID_BUILDS_PERMISSIONS_COUNT
        envman add --key ANDROID_PERMISSIONS_COUNT --value $ANDROID_PERMISSIONS_COUNT
        grep "<uses-permission" apk_decompiled/AndroidManifest.xml > list_android_permissions.txt
        gsed -ri 's/<uses-permission android:name="//g' list_android_permissions.txt
        gsed -ri 's/"\/>//g' list_android_permissions.txt
        cp list_android_permissions.txt /Users/vagrant/deploy/list_android_permissions.txt
    fi

    # SIZE CHECK - if the size of the new apk bigger than the size set into build_config/released_app_infos.sh
    APK_SIZE_WITH_ALERT_THRESHOLD=$(($android_apk_size + $alert_threshold))
    if [ $ANDROID_NEW_APP_SIZE_MB -gt $APK_SIZE_WITH_ALERT_THRESHOLD ]; then
        NEW_APK_SIZE=$ANDROID_NEW_APP_SIZE_MB
        envman add --key NEW_APK_SIZE --value $NEW_APK_SIZE
    fi
fi

if [[ ${check_ios} == "yes" ]]; then
    if [[ ${ios_app_name} == "" ]]; then
        echo "ERROR: Didn't find any ios app name ios_app_name: $ios_app_name"
        exit 1
    fi

    if [[ ${outside_build_slug} != ""  ]]; then
        # we will download the artifact and decompile
        # dl artifact specific for ios
        IOS_DATA_FROM_ARTIFACTS=$(echo $BUILD_ARTIFACTS | jq '.data[] | select (.artifact_type == "ios-ipa")')

        if [[ ${IOS_DATA_FROM_ARTIFACTS} == "" ]]; then
            echo "ERROR: Didn't find any ipa file in your main build with slug: $outside_build_slug"
            exit 1
        fi

        IOS_DATA_SLUG=$(echo $IOS_DATA_FROM_ARTIFACTS | jq '.slug' | sed 's/"//g')
        IOS_NEW_APP_SIZE=$(echo $IOS_DATA_FROM_ARTIFACTS | jq '.file_size_bytes' | sed 's/"//g')
        IOS_NEW_APP_SIZE_MB=$(echo "$IOS_NEW_APP_SIZE / 1024^2" | bc)
        IOS_IPA_URL=$(curl -X GET "https://api.bitrise.io/v0.1/apps/${BITRISE_APP_SLUG}/builds/${outside_build_slug}/artifacts/${IOS_DATA_SLUG}" -H "accept: application/json" -H "Authorization: ${BITRISE_TOKEN}" | jq '.data.expiring_download_url' | sed 's/"//g')

        # dl ios ipa
        curl -X GET ${IOS_IPA_URL} -o ios.ipa

        mkdir ios_unzipped
        unzip ios.ipa
        mv Payload ios_unzipped/
    else
        # we will decompile the ipa from ios_ipa_path
        if [[ ${ios_ipa_path} == "" ]]; then
            echo "ERROR: Didn't find any apk file, please check ios ipa path (ios_ipa_path=$ios_ipa_path)"
            exit 1
        fi

        mkdir ios_unzipped
        unzip $ios_ipa_path -d ios_unzipped/
    fi

    # PERMISSION CHECK - count permissions which are into current info.plist
    CURRENT_IOS_BUILDS_PERMISSIONS_COUNT=$(grep -o -i "UsageDescription</key>" ios_unzipped/Payload/$ios_app_name.app/Info.plist | wc -l)
    if [ $CURRENT_IOS_BUILDS_PERMISSIONS_COUNT -gt $ios_permission_count ]; then
        IOS_PERMISSIONS_COUNT=$CURRENT_IOS_BUILDS_PERMISSIONS_COUNT
        envman add --key IOS_PERMISSIONS_COUNT --value $IOS_PERMISSIONS_COUNT
        grep "UsageDescription</key>" $IOS_PLIST_PATH > list_ios_permissions.txt
        gsed -ri 's/<key>//g' list_ios_permissions.txt
        gsed -ri 's/<\/key>//g' list_ios_permissions.txt
        cp list_ios_permissions.txt /Users/vagrant/deploy/list_ios_permissions.txt
    fi

    # SIZE CHECK - if the size of the new ipa bigger than the size set into build_config/released_app_infos.sh
    IPA_SIZE_WITH_ALERT_THRESHOLD=$(($ios_ipa_size + $alert_threshold))
    if [ $IOS_NEW_APP_SIZE_MB -gt $IPA_SIZE_WITH_ALERT_THRESHOLD ]; then
        NEW_IPA_SIZE=$IOS_NEW_APP_SIZE_MB
        envman add --key NEW_IPA_SIZE --value $NEW_IPA_SIZE
    fi
fi

echo "---- REPORT ----"

printf "QUALITY REPORT\n\n\n" > quality_report.txt
printf ">>>>>>>>>>  CURRENT APP  <<<<<<<<<<\n" >> quality_report.txt
printf "Android permission count : $android_permission_count \n" >> quality_report.txt
printf "Android APK: $android_apk_size MB \n" >> quality_report.txt
printf "iOS permission count : $ios_permission_count \n" >> quality_report.txt
printf "iOS IPA: $ios_ipa_size MB \n" >> quality_report.txt

printf "\n\n" >> quality_report.txt

if [[ ${check_android} == "yes" ]]; then
    printf ">>>>>>>>>>  ANDROID  <<<<<<<<<< \n" >> quality_report.txt
    if [[ ${ANDROID_PERMISSIONS_COUNT} != "" ]]; then
    printf "!!! New Android permissions have been added !!!\n" >> quality_report.txt
    printf "We had: $android_permission_count permissions \n" >> quality_report.txt
    printf "And now: $ANDROID_PERMISSIONS_COUNT permissions \n" >> quality_report.txt
    printf "You can see list of permissions into list_android_permissions.txt \n\n" >> quality_report.txt
    fi
    if [[ ${NEW_APK_SIZE} != "" ]]; then
    printf "!!! New Android apk is bigger !!!\n" >> quality_report.txt
    printf "It weighed: $android_apk_size MB \n" >> quality_report.txt
    printf "And now: $NEW_APK_SIZE MB \n" >> quality_report.txt
    fi
    if [[ ${ANDROID_PERMISSIONS_COUNT} == "" && ${NEW_APK_SIZE} == ""  ]]; then
    printf "0 alert\n" >> quality_report.txt
    fi
    printf "\n\n" >> quality_report.txt
fi

if [[ ${check_ios} == "yes" ]]; then
    printf ">>>>>>>>>>  IOS  <<<<<<<<<< \n" >> quality_report.txt
    if [[ ${IOS_PERMISSIONS_COUNT} != "" ]]; then
    printf "!!! New iOS permissions have been added !!!\n" >> quality_report.txt
    printf "We had: $ios_permission_count permissions \n" >> quality_report.txt
    printf "And now: $IOS_PERMISSIONS_COUNT permissions \n" >> quality_report.txt
    printf "You can see list of permissions into list_ios_permissions.txt \n\n" >> quality_report.txt
    fi
    if [[ ${NEW_IPA_SIZE} != "" ]]; then
    printf "!!! New iOS ipa is bigger !!!\n" >> quality_report.txt
    printf "It weighed: $ios_ipa_size MB \n" >> quality_report.txt
    printf "And now: $NEW_IPA_SIZE MB \n\n" >> quality_report.txt
    fi
    if [[ ${IOS_PERMISSIONS_COUNT} == "" && ${NEW_IPA_SIZE} == ""  ]]; then
    printf "0 alert\n" >> quality_report.txt
    fi
    printf "\n\n" >> quality_report.txt
fi

cp quality_report.txt /Users/vagrant/deploy/quality_report.txt || true

if [[ ${ANDROID_PERMISSIONS_COUNT} != "" || ${NEW_APK_SIZE} != "" || ${IOS_PERMISSIONS_COUNT} != "" || ${NEW_IPA_SIZE} != ""  ]]; then
    echo "Generate an error due to quality alert"
    exit 1
fi
exit 0