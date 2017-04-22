$script:DSCModuleName      = 'xStorage'
$script:DSCResourceName    = 'MSFT_xWaitForDisk'

Import-Module -Name (Join-Path -Path (Join-Path -Path (Split-Path $PSScriptRoot -Parent) -ChildPath 'TestHelpers') -ChildPath 'CommonTestHelper.psm1') -Global

#region HEADER
# Integration Test Template Version: 1.1.1
[string] $script:moduleRoot = Join-Path -Path $(Split-Path -Parent (Split-Path -Parent (Split-Path -Parent $Script:MyInvocation.MyCommand.Path))) -ChildPath 'Modules\xStorage'
if ( (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests'))) -or `
     (-not (Test-Path -Path (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1'))) )
{
    & git @('clone','https://github.com/PowerShell/DscResource.Tests.git',(Join-Path -Path $script:moduleRoot -ChildPath '\DSCResource.Tests\'))
}

Import-Module (Join-Path -Path $script:moduleRoot -ChildPath 'DSCResource.Tests\TestHelper.psm1') -Force
$TestEnvironment = Initialize-TestEnvironment `
    -DSCModuleName $script:DSCModuleName `
    -DSCResourceName $script:DSCResourceName `
    -TestType Integration
#endregion

# Using try/finally to always cleanup even if something awful happens.
try
{
    #region Integration Tests
    $ConfigFile = Join-Path -Path $PSScriptRoot -ChildPath "$($script:DSCResourceName).config.ps1"
    . $ConfigFile -Verbose -ErrorAction Stop

    Describe "$($script:DSCResourceName)_Integration" {
        # Create a VHDx and attach it to the computer
        BeforeAll {
            $VHDPath = Join-Path -Path $TestDrive `
                -ChildPath 'TestDisk.vhdx'
            New-VHD -Path $VHDPath -SizeBytes 1GB -Dynamic
            Mount-DiskImage -ImagePath $VHDPath -StorageType VHDX -NoDriveLetter
            $Disk = Get-Disk | Where-Object -FilterScript {
                $_.Location -eq $VHDPath
            }
        }

        Context 'Wait for a Disk using Disk Number' {
            #region DEFAULT TESTS

            It 'Should compile without throwing' {
                {
                    # This is to pass to the Config
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName         = 'localhost'
                                DiskId           = $disk.Number
                                DiskIdType       = 'Number'
                                RetryIntervalSec = 1
                                RetryCount       = 5
                            }
                        )
                    }

                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData
                    Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
                } | Should not throw
            }

            It 'should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
            }
            #endregion

            It 'Should have set the resource and all the parameters should match' {
                $current = Get-DscConfiguration | Where-Object {
                    $_.ConfigurationName -eq "$($script:DSCResourceName)_Config"
                }
                $current.DiskId           | Should Be $Disk.Number
                $current.RetryIntervalSec | Should Be 1
                $current.RetryCount       | Should Be 5
            }
        }

        Context 'Wait for a Disk using Disk Unique Id' {
            #region DEFAULT TESTS

            It 'Should compile without throwing' {
                {
                    # This is to pass to the Config
                    $configData = @{
                        AllNodes = @(
                            @{
                                NodeName         = 'localhost'
                                DiskId           = $disk.UniqueId
                                DiskIdType       = 'UniqueId'
                                RetryIntervalSec = 1
                                RetryCount       = 5
                            }
                        )
                    }

                    & "$($script:DSCResourceName)_Config" `
                        -OutputPath $TestDrive `
                        -ConfigurationData $configData
                    Start-DscConfiguration -Path $TestDrive -ComputerName localhost -Wait -Verbose -Force
                } | Should not throw
            }

            It 'should be able to call Get-DscConfiguration without throwing' {
                { Get-DscConfiguration -Verbose -ErrorAction Stop } | Should Not throw
            }
            #endregion

            It 'Should have set the resource and all the parameters should match' {
                $current = Get-DscConfiguration | Where-Object {
                    $_.ConfigurationName -eq "$($script:DSCResourceName)_Config"
                }
                $current.DiskId           | Should Be $Disk.UniqueId
                $current.RetryIntervalSec | Should Be 1
                $current.RetryCount       | Should Be 5
            }
        }

        AfterAll {
            Dismount-DiskImage -ImagePath $VHDPath -StorageType VHDx
            Remove-Item -Path $VHDPath -Force
        }
    }
    #endregion
}
finally
{
    #region FOOTER
    Restore-TestEnvironment -TestEnvironment $TestEnvironment
    #endregion
}
