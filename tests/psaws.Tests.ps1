$ModuleName = 'psaws'

# http://www.lazywinadmin.com/2016/05/using-pester-to-test-your-manifest-file.html
# Make sure one or multiple versions of the module are not loaded
Get-Module -Name $ModuleName | Remove-Module

# Find the Manifest file
$ManifestFile = "$(Split-path (Split-Path -Parent -Path $MyInvocation.MyCommand.Definition))\$ModuleName\$ModuleName.psd1"

# Import the module and store the information about the module
$ModuleInformation = Import-Module -Name $ManifestFile -PassThru


Describe "$ModuleName Module - Testing Manifest File (.psd1)"{
    Context 'Manifest'{
        It 'Should contain RootModule'{
            $ModuleInformation.RootModule | Should not BeNullOrEmpty
        }
        It 'Should contain Author'{
            $ModuleInformation.Author | Should not BeNullOrEmpty
        }
        It 'Should contain Company Name'{
            $ModuleInformation.CompanyName | Should not BeNullOrEmpty
        }
        It 'Should contain Description'{
            $ModuleInformation.Description | Should not BeNullOrEmpty
        }
        It 'Should contain Copyright'{
            $ModuleInformation.Copyright | Should not BeNullOrEmpty
        }
        It 'Should contain License'{
            $ModuleInformation.LicenseURI | Should not BeNullOrEmpty
        }
        It 'Should contain a Project Link'{
            $ModuleInformation.ProjectURI | Should not BeNullOrEmpty
        }
        It 'Should contain Tags (For the PSGallery)'{
            $ModuleInformation.Tags.count | Should not BeNullOrEmpty
        }
    }
}

InModuleScope 'psaws' {
  Describe 'psaws' {
    Context 'Testing Connect-AwsMfa' {
      Mock -CommandName Get-IAMMFADevice -MockWith {
        return @{
          SerialNumber = 'arn:aws:iam::111111111111:mfa/me@email.com.au'
        }
      }

      Mock -CommandName Get-STSSessionToken -MockWith {
        return @{
          AccessKey = 'ASIAIRAOHDFIYJBKF4GA'
          SecretKey = 'LC8/e/IfDbLHBhnVkIEfhFgaA4/FQel8FLRuUrXeS'
          SessionToken = 'FQoDYXdzEOP//////////wEaDHp0FwMRVel8FLRuyKvAW+KrrwLyN2z5E42WSOduMlXMiZF5op2HwFjXBhh2VT8f8k2t4g1yaI9+flvbpd/f1b7'
        }
      }
  
      It 'should not accept MFA Tokens shorter than 6 digits' {
        {Connect-AwsMfa -region ap-southeast-2 -awsUserName me@david-obrien.net -awsProfile default -mfaToken 12345} | Should throw
      }
  
      It 'should not accept MFA Tokens longer than 6 digits' {
        {Connect-AwsMfa -region ap-southeast-2 -awsUserName me@david-obrien.net -awsProfile default -mfaToken 1234567} | Should throw
      }
    
      It 'should accept known AWS regions (Jan 2017)' {
        $regions = Get-AWSRegion
        foreach ($region in $regions) {
          $region
          {Connect-AwsMfa -region $region -awsUserName me@david-obrien.net -awsProfile default -mfaToken 123456} | Should not throw
        }
      }
    
      It 'should throw with unknown AWS region' {
        {Connect-AwsMfa -region 'ant-verycold-1' -awsUserName me@david-obrien.net -awsProfile default -mfaToken 123456} | Should throw
      }
  
      It 'checks the output of Connect-AwsMfa' {
        Connect-AwsMfa -region ap-southeast-2 -awsUserName me@david-obrien.net -awsProfile default -mfaToken 123456 | Should BeOfType Hashtable
        (Connect-AwsMfa -region ap-southeast-2 -awsUserName me@david-obrien.net -awsProfile default -mfaToken 123456).AccessKey | Should BeExactly 'ASIAIRAOHDFIYJBKF4GA'
        (Connect-AwsMfa -region ap-southeast-2 -awsUserName me@david-obrien.net -awsProfile default -mfaToken 123456).SecretKey | Should BeExactly 'LC8/e/IfDbLHBhnVkIEfhFgaA4/FQel8FLRuUrXeS'
        (Connect-AwsMfa -region ap-southeast-2 -awsUserName me@david-obrien.net -awsProfile default -mfaToken 123456).SessionToken | Should BeExactly 'FQoDYXdzEOP//////////wEaDHp0FwMRVel8FLRuyKvAW+KrrwLyN2z5E42WSOduMlXMiZF5op2HwFjXBhh2VT8f8k2t4g1yaI9+flvbpd/f1b7'
      }
    }
  }
}
