# GitHub Issues To Csv
A PowerShell script for exporting all issues of a repository to a CSV file

## <a name="about">About</a>

This script will download the most commonly used fields for issues from a GitHub repository and write them to a CSV file. This CSV file can then be opened and analyzed with Microsoft Excel or other tools.

The script will run on any Windows device that has least PowerShell 4.0 installed.

An example of the CSV file it generates is available: [Example.csv](https://github.com/texhex/GHIssuesToCsv/blob/master/Example.csv)  
 
## <a name="usage">Usage</a>

 * Download the [newest release](https://github.com/texhex/GHIssuesToCsv/releases/latest).
 * Extract all files in the archive to a folder

Configure the script to run with your username, token and repository: 

 * Right click ``GHIssuesToCsv.ps1`` and select *Edit...*
 * Set ``$Repo_Path=`` to the container and the name of the repository you want to export the issues for 
 * Set ``$Authentication_User`` to your GitHub username 
 * Set ``$Authentication_Token`` to a GitHub token (password) you can create using the [New token]( https://github.com/settings/tokens/new) section of your user preferences. You only need to activate the scope *REPO* if you want to access a private repository. For public repositories, no scope is needed.  
 * Save the file
 * Execute ``_Start.bat`` and the script will run
 * When everything works, you’ll find the CSV file in the same folder as `` IssuesExport.csv``

More description for each entry is in ``GHIssuesToCsv.ps1`` directly.

## <a name="contributions">Contributions</a>
Any constructive contribution is very welcome! 

If you encounter a bug or have a suggestions, please open a [new issue](https://github.com/texhex/GHIssuesToCsv/issues/new).

## <a name="license">License</a>
``GHIssuesToCsv.ps1``, ``GHPS.psm1`` and ``MPSXM.psm1``: Copyright © 2015-2017 [Michael Hex](http://www.texhex.info/). Licensed under the **Apache 2 License**. For details, please see LICENSE.txt.
 

