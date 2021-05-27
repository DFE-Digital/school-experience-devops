echo Build Source Branch is $BUILD_SOURCEBRANCHNAME

if [ $BUILD_SOURCEBRANCHNAME == 'master' ] ; then
  echo "##vso[task.setvariable variable=schoolExperienceImageTag]v${BUILD_BUILDID}"
  echo "##vso[task.setvariable variable=schoolExperienceImageTagStable]v${BUILD_BUILDID}-stable"
elif [ $BUILD_SOURCEBRANCHNAME == 'merge' ] ; then
  echo "##vso[task.setvariable variable=schoolExperienceImageTag]v${BUILD_BUILDID}-review"
  echo "##vso[task.setvariable variable=schoolExperienceImageTagStable]v${BUILD_BUILDID}-stable"
else
  echo "##vso[task.setvariable variable=schoolExperienceImageTag]v${BUILD_BUILDID}-${BUILD_SOURCEBRANCHNAME}"
  echo "##vso[task.setvariable variable=schoolExperienceImageTagStable]v${BUILD_BUILDID}-${BUILD_SOURCEBRANCHNAME}-stable"
fi

echo "##vso[task.setvariable variable=agentIpAddress]$(curl -s https://api.ipify.org)"
