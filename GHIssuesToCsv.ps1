<#
 GitHub Issues to Csv
 Copyright © 2017 Michael 'Tex' Hex 
 Licensed under the Apache License, Version 2.0. 

 https://github.com/texhex/GHIssuesToCsv
#>


##########################################################################################

<#
 Set this to the username and path of the repository you wish to retrive the issues for.
 For example, if you view your GitHub repository in a browser and the URL is:
  https://github.com/johndoe/SuperApp
 then this path should be set to
  johndoe/SuperApp
#>
$Repo_Path="texhex/GHIssuesToCsv"

<#
 For public repositories, no authentication is required, so these fields can be left empty. 
 However, when you use the script more often, GitHub may respond with a 403 error because 
 the number of calls that can be used without authentication is limited. 

 First, enter your username. That's your "real" username in GitHub, without any @ in it.
 You can find it when been logged in to GitHub, then clicking your user menu in the top
 row (last item to the right). It will say "Signed in as USERNAME" in the first line.
#>
$Authentication_User=""

<#
 For the token, open
  https://github.com/settings/tokens/new
 with your browser to generate a new token. 
 
 If you want to access a private repository, you need to select the scope "repo"; for 
 public repositories no scope is needed. 
 
 It should look something like this: 
 b4baea6279b3ecf7279a2d1b062452cfc8956fe1
#>
$Authentication_Token=""


##########################################################################################





#Script version
$scriptversion="0.2.1"

#This script requires PowerShell 4.0 or higher 
#requires -version 4.0

#Guard against common code errors
Set-StrictMode -version 2.0

#Stop on errors
#$ErrorActionPreference = 'Stop'

#Import GitHub module
Import-Module $PSScriptRoot\GHPS.psm1 -Force

#Import Module with some helper functions
Import-Module $PSScriptRoot\MPSXM.psm1 -Force

#The CSV file will be saved to this location
Set-Variable CSV_FILE "$PSScriptRoot\IssuesExport.csv" –option ReadOnly -Force


function ConvertFrom-GHIssueJsonArray()
{
<#
  .SYNOPSIS
  Converts a GutHub issue JSON array to an array of dictionary objects for export

  .PARAMETER RawData
  An array of strings with JSON data

  .OUTPUTS
  An array of dictionary objects containing the issue data
#>
param (
  [Parameter(Mandatory=$True)]
  $RawData
)
    #Make sure the input is an array, even if none or only only one issue was returned
    $raw=ConvertTo-Array $RawData
    
    #create array that later on holds all issues
    $listExport=@()

    #Because of pagenation, we might have several json "buckets"
    foreach($entry in $raw)
    {
        $issuesRaw=ConvertFrom-Json $entry

        foreach($jsonIssue in $issuesRaw)
        {
            #We use a dictionary because we want to have the fields in the order we add them
            $issue=New-Dictionary -StringPairs

            $issue.Add("Number", "$($jsonIssue.number)")
            $issue.Add("Title", "$($jsonIssue.title)")
            $issue.Add("State", "$($jsonIssue.state)")
            
            #Labels (Tags)
            $labelList=""
            if ( $jsonIssue.labels ) 
            {
                foreach($label in $jsonIssue.labels)
                {
                    $labelList += "$($label.name); "                    
                }
                $labelList=Get-TrimmedString $labelList -Equalize 
            }
            $issue.Add("Labels", $labelList)

            $issue.Add("Creation Date", "$($jsonIssue.created_at)")
            $issue.Add("Last Update Date", "$($jsonIssue.updated_at)")
            $issue.Add("Close Date", "$($jsonIssue.closed_at)")            
            
            $issue.Add("Locked", "$($jsonIssue.locked)")        
            $issue.Add("URL", "$($jsonIssue.html_url)")

            $issue.Add("Creator", "$($jsonIssue.user.login)")
            $issue.Add("Creator URL", "$($jsonIssue.user.html_url)")

            if ( $jsonIssue.assignee )
            {
                $issue.Add("Assigned To", "$($jsonIssue.assignee.login)")
                $issue.Add("Assigned To URL", "$($jsonIssue.assignee.html_url)")
            }
            else
            {
                $issue.Add("Assigned To", "")
                $issue.Add("Assigned To URL", "")  
            }

            if ( $jsonIssue.milestone )
            {
                #has milestone
                $issue.Add("Milestone Number", "$($jsonIssue.milestone.number)")
                $issue.Add("Milestone Title", "$($jsonIssue.milestone.title)")
                $issue.Add("Milestone State", "$($jsonIssue.milestone.state)")
                $issue.Add("Milestone URL", "$($jsonIssue.milestone.html_url)")
            }
            else
            {
                #write empty fields
                $issue.Add("Milestone Number", "")
                $issue.Add("Milestone Title", "")
                $issue.Add("Milestone State", "")
                $issue.Add("Milestone URL", "")            
            }



            $listExport += $issue
        }

    } #foreach RAW

    
    return $listExport
}


function ConvertTo-CsvFileStringArray()
{
<#
  .SYNOPSIS
  Converts an array of hashtable or dictionary objects to an array of strings in CSV format. First entry contains the field names.

  .PARAMETER InputObjects
  An array of hashtable or dictionary objects to be converted to CSV

  .OUTPUTS
  A single string that can be saved as is as *.csv file
#>
param (
  [Parameter(Mandatory=$True)]
  $InputObjects
)
    #Export-Csv can't handle hashtable or dictionary objects very well, so we need this function

    Set-Variable FIELD_DELIMETER "," –option ReadOnly -Force
    Set-Variable ROW_DELIMETER "`r`n" –option ReadOnly -Force

    #This will later on contain the csv lines
    $csvLines=@()

    #For the header line, grab the first result
    $issue=$InputObjects[0]
    $headerLine=""
    foreach($key in $issue.Keys)
    {
        #remove any whitespaces from the name
        $name=Get-TrimmedString -String $key -RemoveAll
        $headerLine += "$name$($FIELD_DELIMETER)"
    }

    #remove the last ","
    $headerLine=$headerLine.Substring(0,$headerLine.Length-1) #Substring starts at zero so this -1 is actually -2

    #Add the head as the first line
    $csvLines += "$headerLine"


    #Now add the content
    foreach($issue in $InputObjects)
    {
        $line=""
        foreach($key in $issue.Keys)
        {
            $data=$issue[$key]
            #replace " with ""
            $data=$data.Replace("""","""""")
            $data="""$data""$($FIELD_DELIMETER)"
            $line += $data
        }
        
        $line=$line.Substring(0,$line.Length-1) #remove final ","

        $csvLines += "$line"
    }

    #return $csvLines

    $csv=""
    #concat the final string 
    foreach($line in $csvLines)
    {
        $csv += $line
        $csv += $ROW_DELIMETER
    }

    return $csv
}


######## MAIN SCRIPT ########

$banner=@"
GitHub Issues To CSV - Version @@VERSION@@
Copyright © 2015-2017 Michael 'Tex' Hex
https://github.com/texhex/GHIssuesToCsv

"@
$banner=$banner -replace "@@VERSION@@", $scriptversion

write-host $banner

write-host "Trying to access data for [$($Repo_Path)]..."

$url="https://api.github.com/repos/@@REPO_PATH@@/issues?state=all&per_page=100"
$url=$url.Replace("@@REPO_PATH@@", $Repo_Path)
$rawResults=Invoke-GHDataRetrival -Url $url -AuthenticationUser $Authentication_User -AuthenticationToken $Authentication_Token

write-host "  Done."

$results=ConvertFrom-GHIssueJsonArray $rawResults

#Make sure it's an array
$issuesExport=ConvertTo-Array $results

if ($issuesExport.Length -le 0)
{
    write-host "No issues found!"
}
else
{
    write-host "A total of $($issuesExport.Length) issue(s) was found"

    $csv=ConvertTo-CsvFileStringArray $issuesExport
    out-file -FilePath $CSV_FILE -InputObject $csv -Encoding utf8 -Force

    write-host "CSV file written to: $CSV_FILE"
}

write-host "`r`nScript finished, please come again!"

