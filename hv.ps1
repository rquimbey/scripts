#Hyper-V VSS backup is a PowerShell script written by Robert 'Q' Quimbey.
#Send Feedback to rquimbey@purestorage.com
#Version 1.0.6

Function New-VSSHVBackup{
    <#
    .SYNOPSIS
    Create a VSS Snapshot of a Hyper-V Volume on Pure Flash Array.
    
    .DESCRIPTION
    Create a VSS Snapshot on Hyper-V Servers that are connected directly to the Pure Storage Flash Array.
    The FlashArray needs to be added to the Pure Storage Hardware VSS Provider using pureproviderconfig.exe

    Install the Pure Storage VSS Hardware Provider from: https://github.com/PureStorage-Connect/VSS-Provider
    Run the pureproviderconfig.exe in c:\program files\pure storage\vss\provider to add the FlashArray.

    For example:
    pureproviderconfig add --url https://ipaddress.of.flasharray --user USERNAME FlashArrayFriendlyName

    This script is simply calling the built-in VSS Requestor, Diskshadow. The DiskShadow Syntax is as follows:

    Set context persistent
    Set option transportable
    Set metadata "c:\program files\pure storage\vss\hv\$CABFileName.cab"
    Begin backup
    Add volume $Path Provider {781c006a-5829-4a25-81e3-d5e43bd005ab}
    Create
    End backup
    exit

    The Cabfile is used to expose (mount) a snapshot. In the Hyper-V world this is almost never utilized because
    most Hyper-V in production is in a Failover Cluster which would have a disk signature collision. It is better
    to utilize the PureStoragePowerShellSDK2 or manually in the FlashArray GUI to copy the snapshot to a new volume
    that is outside of the cluster.  Then either copy remotely over SMB, or on the remote server, change the disk signature
    and disconnect the volume from the remote server. Then connect that volume to the Hyper-V cluster and copy the files off.

    For a detailed walkthrough on changing the disk signature to enable onlining a clone on a failover cluster, see: 
    https://support.purestorage.com/bundle/m_microsoft_platform_guide/page/Solutions/Microsoft_Platform_Guide/Failover_Clustering_Feature/topics/concept/c_using_a_clustered_shared_volume_snapshot.html

    The Cabfile can also be used to restore. This is also almost never performed in a Hyper-V environment because
    more than 1 VM are usually co-located on the same volume. VSS restore is only a point-in-time restore that reverts
    all volumes in the backup set to that point in time impacting everything, all VMs, on the volumes. 

    .EXAMPLE
    Backup Cluster Shared Volume C:\ClusterStorage\Volume1
    New-VSSHVBackup -Path "C:\clusterstorage\volume1"
    #>

    Param(
        [Parameter(ParameterSetName="backup", Mandatory=$true)]
        [parameter(Position=0)]
        [string]$Path
    )
    Begin{
        New-Item -itemtype directory -path "C:\program files\pure storage\vss\hv" -ErrorAction SilentlyContinue
        #date+timestamp to use in the cab file name
        $CABFileName = Get-Date -uFormat "%m_%d_%Y__%H%M_%S"
    }
    
    Process{
        #This section is adding the diskshadow commands to a temp file to be executed
    
        #Note: Diskshadow script fails if you try to add the same volume twice because it can't handle the error via txt file
    
            $script = "./$CABFileName.dsh"
            "Set context persistent" | Add-Content $script
            "Set option transportable" | Add-Content $script 
            "Set metadata ""c:\program files\pure storage\vss\hv\$CABFileName.cab""" | Add-Content $script
            "Begin backup" | Add-Content $script
            'Add volume '+$Path+' Provider {781c006a-5829-4a25-81e3-d5e43bd005ab}'| Add-Content $script
            "Create" | Add-Content $script
            "End backup" | Add-Content $script
            "exit" | Add-Content $script
        
            diskshadow /s $script
            Remove-Item $script

            $BackupCompleteTime = Get-Date -uFormat "%m-%d-%Y--%H%M-%S"
            Write-Host -ForeGroundColor white "Ending Backup of $Path at $BackupCompleteTime"
        }
    End{
        }
}