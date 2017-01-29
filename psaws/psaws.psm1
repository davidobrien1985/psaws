Function Connect-AwsMfa {
  param (
    [Parameter(mandatory=$true,HelpMessage='Specify the AWS region')]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [string]$region,
    [string]$awsProfile = 'default',
    [Parameter(mandatory=$true,HelpMessage='Specify the user name associated with this profile and MFA token')]
    [string]$awsUserName,
    [Parameter(mandatory=$true,HelpMessage='Specify the MFA Token that is currently valid')]
    [ValidateLength(6,6)]
    [string]$mfaToken
  )

  $parameters = @{
    'Region' = $region
    'ProfileName' = $awsProfile
    'UserName' = $awsUserName
  }

  $mfaDeviceArn = (Get-IAMMFADevice @parameters).SerialNumber

  $parameters = @{
    DurationInSeconds = 900
    TokenCode = $mfaToken
    SerialNumber = $mfaDeviceArn
    ProfileName = $awsProfile
    Region = $region
  }

  $sts = Get-STSSessionToken -DurationInSeconds 900 -SerialNumber $mfaDeviceArn -TokenCode $mfaToken -Region $region -ProfileName $awsProfile -Verbose
  $sts
}

Function Get-AwsEc2WithPublicIp {
  param (
    [Parameter()]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [AllowEmptyString()]
    [string]$region = ''
  )

  if ($region -eq '') {

    $ec2CfnInstances = (Get-EC2Instance).Where{$PSItem.Instances.PublicIpAddress -ne $null}
    $ec2CfnInstances.Instances.InstanceId

  }
  else {
    $ec2CfnInstances = (Get-EC2Instance -Region $region).Where{$PSItem.Instances.PublicIpAddress -ne $null}
    $ec2CfnInstances.Instances.InstanceId
  }
}
