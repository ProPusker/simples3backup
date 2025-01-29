Backup Script Setup Guide

This guide provides step-by-step instructions to set up and use the PowerShell backup script, which creates shadow copies of specified directories and syncs them to an AWS S3 bucket. The script also includes functionality to delete old backups based on a retention policy.

 Prerequisites

Before using the script, ensure the following prerequisites are met:

1. **PowerShell Version 5**:
   - The script requires PowerShell version 5. Check your PowerShell version by running:
     ```powershell
     $PSVersionTable.PSVersion
     ```
   - If you need to install or upgrade PowerShell, follow the official [PowerShell installation guide](https://learn.microsoft.com/en-us/powershell/scripting/install/installing-powershell).

2. **AWS CLI Installed and Configured**:
   - Install the AWS CLI by following the [official AWS CLI installation guide](https://docs.aws.amazon.com/cli/latest/userguide/install-cliv2.html).
   - Configure the AWS CLI with your credentials by running:
     ```powershell
     aws configure
     ```
     Provide your AWS Access Key, Secret Key, default region, and output format when prompted.

3. **Administrator Privileges**:
   - The script must be run with administrator privileges to create shadow copies and manage symbolic links.

4. **XML Configuration File**:
   - Create an XML configuration file (`backup.xml`) that defines the volumes, directories, and retention policies for the backup tasks. See the [Sample XML Configuration](#sample-xml-configuration) section for details.



## Setup Instructions

### 1. Download or Clone the Script
- Download the PowerShell script (`BackupScript.ps1`) or clone the repository containing the script.
- Save the script to a directory on your system, e.g., `C:\BackupScript`.

### 2. Create the XML Configuration File
- Create an XML file named `backup.xml` in the same directory as the script.
- Use the following sample structure for the XML file:

#### Sample XML Configuration
```xml
<XXX>
  <Volume>
    <Drive>C</Drive>
    <Task>
      <Id>Documents</Id>
      <Path>C:\Users\Admin\Documents</Path>
      <KeepDays>30</KeepDays>
    </Task>
    <Task>
      <Id>Projects</Id>
      <Path>C:\Projects</Path>
      <KeepDays>60</KeepDays>
    </Task>
  </Volume>
  <Volume>
    <Drive>D</Drive>
    <Task>
      <Id>Backups</Id>
      <Path>D:\Backups</Path>
      <KeepDays>90</KeepDays>
    </Task>
  </Volume>
</XXX>
```

- Replace the `<Drive>`, `<Path>`, and `<KeepDays>` values with the appropriate values for your system.

### 3. Configure the Script (Optional)
- The script uses default values for the configuration file (`backup.xml`) and log directory (`logs`). If you want to change these, modify the script's parameters at the top of the file:
  ```powershell
  param (
      [string]$ConfigFile = "$PSScriptRoot\backup.xml",
      [string]$LogPath = "$PSScriptRoot\logs"
  )
  ```

### 4. Run the Script
- Open PowerShell as an administrator.
- Navigate to the directory where the script is located:
  ```powershell
  cd C:\BackupScript
  ```
- Run the script:
  ```powershell
  .\BackupScript.ps1
  ```

---

## How It Works

### Key Features
1. **Shadow Copy Creation**:
   - The script creates a shadow copy (Volume Snapshot) of the specified drive using Windows Volume Shadow Copy Service (VSS).

2. **Symbolic Link Creation**:
   - A symbolic link is created to the shadow copy, allowing access to the snapshot.

3. **Sync to S3**:
   - The script uses the AWS CLI to sync the specified directories to an S3 bucket.

4. **Retention Policy**:
   - Old backups in S3 are deleted based on the retention policy defined in the XML configuration.

5. **Logging**:
   - All actions and errors are logged to a file in the `logs` directory.

### Script Workflow
1. Checks for PowerShell version 5 and administrator privileges.
2. Validates the XML configuration file.
3. Creates a shadow copy for each volume specified in the configuration.
4. Syncs the specified directories to the S3 bucket.
5. Deletes old backups from S3 based on the retention policy.
6. Cleans up shadow copies and symbolic links.

---

## Troubleshooting

### Common Issues
1. **PowerShell Version Mismatch**:
   - Ensure you are using PowerShell version 5. Upgrade if necessary.

2. **AWS CLI Not Configured**:
   - Run `aws configure` to set up your AWS credentials and region.

3. **Invalid XML Configuration**:
   - Ensure the XML file is correctly formatted and all paths exist on your system.

4. **Access Denied Errors**:
   - Run the script as an administrator.

5. **Shadow Copy Creation Fails**:
   - Ensure the Volume Shadow Copy Service (VSS) is running on your system.

### Logs
- Logs are stored in the `logs` directory within the script's folder. Check the logs for detailed error messages and debugging information.

---

## Example Use Case

### Scenario
- You want to back up the following directories:
  - `C:\Users\Admin\Documents` (retain for 30 days)
  - `C:\Projects` (retain for 60 days)
  - `D:\Backups` (retain for 90 days)

### Steps
1. Create the `backup.xml` file as shown in the [Sample XML Configuration](#sample-xml-configuration) section.
2. Run the script as an administrator.
3. The script will:
   - Create shadow copies of the `C:` and `D:` drives.
   - Sync the specified directories to the S3 bucket.
   - Delete backups older than the specified retention period.



## Notes
- Replace `XXX-backup` in the script with your actual S3 bucket name.
- Ensure the AWS CLI profile (`XXX-backup-user`) matches the profile configured in your AWS CLI.
- Test the script with a small directory before running it on critical data.



## Support
For questions or issues, please contact the script author or refer to the [PowerShell documentation](https://learn.microsoft.com/en-us/powershell/) and [AWS CLI documentation](https://docs.aws.amazon.com/cli/latest/userguide/).

