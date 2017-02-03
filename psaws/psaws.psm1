#requires -Module AwsPowerShell
Function Connect-AwsMfa {
  param (
    [Parameter(mandatory=$true,HelpMessage='Specify the AWS region')]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [string]$region,
    [string]$awsProfile = 'default',
    [Parameter(mandatory=$false)]
    [int]$duration = 900,
    [Parameter(mandatory=$true,HelpMessage='Specify the MFA Token that is currently valid')]
    [ValidateLength(6,6)]
    [string]$mfaToken
  )
  
  $awsUserName = (Get-STSCallerIdentity -Region $region -ProfileName $awsProfile).Arn.Split('/')[1]

  $parameters = @{
    'Region' = $region
    'ProfileName' = $awsProfile
    'UserName' = $awsUserName
  }

  $mfaDeviceArn = (Get-IAMMFADevice @parameters).SerialNumber

  $parameters = @{
    DurationInSeconds = $duration
    TokenCode = $mfaToken
    SerialNumber = $mfaDeviceArn
    ProfileName = $awsProfile
    Region = $region
  }

  $sts = Get-STSSessionToken -DurationInSeconds $duration -SerialNumber $mfaDeviceArn -TokenCode $mfaToken -Region $region -ProfileName $awsProfile -Verbose
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

Function Test-AwsEc2PublicIp {
  [OutputType([System.Boolean])]
  param (
    [Parameter(mandatory=$true,
        HelpMessage='Specifiy Instance Id of EC2 instance',
        ParameterSetName='instanceId'
    )]
    [string]$instanceId,

    [Parameter(
      ParameterSetName='instanceId')]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [string]$region = (Get-DefaultAWSRegion),

    [Parameter(mandatory=$true,
        ParameterSetName='instanceObject',
        ValueFromPipeline=$true
    )]
    [Amazon.EC2.Model.Instance[]]$instanceObject,

    [Parameter(mandatory=$true,
        ParameterSetName='reservationObject',
        ValueFromPipeline=$true
    )]
    [Amazon.EC2.Model.Reservation]$reservationObject
  )

  Begin {

  }
  Process {

    if ($instanceId) {
      Write-Verbose 'instanceId'
      $ec2Instances = (Get-EC2Instance -InstanceId $instanceId -Region $region).Instances
    }

    elseif ($reservationObject) {
      Write-Verbose 'Reservation'
      $ec2Instances = $reservationObject.Instances
    }

    elseif ($instanceObject) {
      Write-Verbose 'instance object'
      $ec2Instances = $instanceObject
    }

    if ($ec2Instances.PublicIpAddress -ne $null) {
      return $true
    }
    else {
      return $false
    }
  }
  End {}
}

Function Get-AwsEc2Windows {
  param (
    [Parameter()]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [AllowEmptyString()]
    [string]$region = ''
  )

  ((Get-EC2Instance -Region $region).Instances).Where({$PSItem.Platform -eq 'Windows'}).InstanceId
}

Function Get-AwsEc2IamInstanceProfileStatus {
  param (
    [Parameter(ParameterSetName='with')]
    [switch]$with,
    [Parameter(ParameterSetName='without')]
    [switch]$without,
    [Parameter()]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [AllowEmptyString()]
    [string]$region = (Get-DefaultAWSRegion)
  )
  if ($with) {
    $ec2Instances = (Get-EC2Instance -Region $region).Where({$PSItem.Instances.IamInstanceProfile -ne $null})
    $ec2Instances.Instances.InstanceId
  }
  if ($without) {
    $ec2Instances = (Get-EC2Instance -Region $region).Where({$PSItem.Instances.IamInstanceProfile -eq $null})
    $ec2Instances.Instances.InstanceId
  }
}

Function Get-AwsEc2IamPolicyDocument {
  param (
    [Parameter()]
    [string]$instanceId
    ,
    [Parameter()]
    [ValidateScript({$_ -cin ([Amazon.RegionEndpoint]::EnumerableAllRegions).SystemName})]
    [AllowEmptyString()]
    [string]$region = "$(Get-DefaultAWSRegion)"
  )
  
  $ec2instance = Get-EC2Instance -InstanceId $instanceId -Region $region
  
  
  $iam = $ec2Instance.Instances.IamInstanceProfile.Arn
  
  [System.Reflection.Assembly]::LoadWithPartialName("System.Web.HttpUtility")
  
  $iamRoleName = (Get-IAMInstanceProfile -InstanceProfileName $iam.Split('/')[1]).Roles.RoleName
  $iamRolePolicies = Get-IAMRolePolicies -RoleName $iamRoleName
  
  foreach ($iamRolePolicy in $iamRolePolicies) {
    $rolePolicy = (Get-IAMRolePolicy -PolicyName $iamRolePolicy -RoleName $iamRoleName).PolicyDocument
    if ($rolePolicy) {
      [System.Web.HttpUtility]::UrlDecode($rolePolicy)
    }
    else {
      $managedPolicies = Get-IAMAttachedRolePolicies -RoleName $iamRoleName
      if ($managedPolicies) {
        foreach ($managedPolicy in $managedPolicies) {
          $policy = Get-IAMPolicy -PolicyArn $managedPolicy.Arn
          [System.Web.HttpUtility]::UrlDecode((Get-IAMPolicyVersion -PolicyArn $policy.Arn -VersionId $policy.DefaultVersionId).Document)
        }
      }
    }
  }
}