<#
 Maybe this will be a GitHub API for PowerShell someday.
 Today is not the day.
 
 Copyright © 2017 Michael 'Tex' Hex 
 Licensed under the Apache License, Version 2.0. 

 Currently only used in this repo:
 https://github.com/texhex/GHIssuesToCsv
#>

#Guard against common code errors
Set-StrictMode -version 2.0

#Import Module with some helper functions
Import-Module $PSScriptRoot\MPSXM.psm1 -Force

#This script requires PowerShell 4.0 or higher 
#requires -version 4.0


#TODO:
# Pagenation, see https://developer.github.com/guides/traversing-with-pagination/
#
# 
# New Function Get-GHAPIUrl -Type Issues -Organization XXX/-User YYY -Reposity ZZZ
# URI building: http://stackoverflow.com/questions/27925896/build-url-string
#     also: http://www.powershellmagazine.com/2012/12/24/pstip-working-with-a-uniform-resource-identifier-uri-in-powershell/
#     also: http://stackoverflow.com/questions/14517798/append-values-to-query-string
#     Uri Builder: https://msdn.microsoft.com/en-us/library/system.uribuilder(v=vs.110).aspx

function ConvertFrom-GHLinkHeader()
{
<#
  .SYNOPSIS
  Parses a GitHub LINK header and returns a hashtable with the entries

  .PARAMETER LinkHeader
  The LINK header returned by the GitHub API function that should be interpreted

  .OUTPUTS
  Hashtable with two fields "rel" and "link"
#>
param (
  [Parameter(Mandatory=$True)]
  [string]$LinkHeader
)

    $relLinks=@{}

    #First check: We expect the length of the string to be at least 80 but not more than 512
    if ( ($LinkHeader.Length -lt 80) -or ($LinkHeader.Length -gt 512) )
    {
        throw New-Exception -InvalidFormat -Explanation "Link header length is not within expected range: $($LinkHeader)"
        
    }
    else
    {
        #We split on "," and expect at least two entries
        $aryRaw=$LinkHeader.Split(',')
 
        if ($aryRaw.Length -lt 2)
        {
            throw New-Exception -InvalidFormat -Explanation  "Link header is not in the expected format: $($LinkHeader)"
        }
        else
        {
            #Work with each entry from the array
            foreach($entry in $aryRaw)
            {
                $entry=Get-TrimmedString $entry

                #Link must be longer than 40 chars
                if ( $entry.Length -lt 40 ) 
                {
                    throw New-Exception -InvalidFormat -Explanation "A part of the link header does not have the required length: $($entry)"
                }
                else
                {
                    #Must start with < and end with "
                    if ( $entry.Substring(0,1) -ne "<" )
                    {
                        throw New-Exception -InvalidFormat -Explanation "A part of the link header does not start with arrow bracket: $($entry)"
                    }
                    else
                    {
                        if ( $entry.Substring($entry.Length-1,1) -ne """" )
                        {
                            throw New-Exception -InvalidFormat -Explanation "A part of the link header does not end with quotation mark: $($entry)"
                        }
                        else
                        {
                            #Split ; rel="
                            $aryLinkRel=$entry.Split(";")
                            if ($aryLinkRel.Length -ne 2)
                            {
                                throw New-Exception -InvalidFormat -Explanation "A part of the link header does not contain the required subparts: $($entry)"
                            }
                            else
                            {
                                #Final checks: does the second part contains "rel="
                                if ( -not (Test-String $aryLinkRel[1] -Contains "rel=") )
                                {
                                    throw New-Exception -InvalidFormat -Explanation "A subpart of the link header does not contain the word REL: $($entry)"
                                }   
                                else
                                {
                                    #Remove < and >
                                    $link=$aryLinkRel[0].Replace("<","").Replace(">","")

                                    #Remove whitespaces
                                    $rel=Get-TrimmedString $aryLinkRel[1]
                                    $rel=$rel.Replace("rel=","").Replace("""","").ToLower()
                                    
                                    $relLinks.Add($rel,$link)

                                }                                                            
                            }
                        }
                    }
                }
            }
        }

    }

 
 return $relLinks
}


function Invoke-GHDataRetrival()
{
<#
  .SYNOPSIS
  Calls a GitHub URL and retrieves all results

  .PARAMETER URL
  The API URL (http://api.github.com/xxxxx) that should be called

  .PARAMETER AuthenticationUser
  The name of the user used for authentication

  .PARAMETER AuthenticationToken
  The token (plain text password) to be used for authentication

  .OUTPUTS
  An array of string values that should contain the JSON result from GitHub
#>
param (
  [Parameter(Mandatory=$True)]
  [string]$URL,

  [Parameter(Mandatory=$False)]
  [string]$AuthenticationUser,

  [Parameter(Mandatory=$False)]
  [string]$AuthenticationToken
)

    #HTTP Header Hashtable
    $headers=@{}

    if ( (Test-String $AuthenticationUser -HasData) -or (Test-String $AuthenticationToken -HasData) )
    {
        #The procedure how to use basic authentication with GitHub with Invoke-WebRequest is from
        #[briantist](http://stackoverflow.com/users/3905079/briantist)
        #and can be found in this answer: 
        #http://stackoverflow.com/a/27951845
        $cred = "$($AuthenticationUser):$($AuthenticationToken)"
        $cred_utf = [System.Text.Encoding]::UTF8.GetBytes($cred)
        $cred_utf_encoded = [System.Convert]::ToBase64String($cred_utf)
        $basicAuthHeaderName = "Basic $cred_utf_encoded"
        $headers += @{ Authorization = $basicAuthHeaderName }
    }

    #Start the requests, there might be some
    $paginationResults=@()
    $uriNextCall=$URL
    $can_continue=$true

    while ($can_continue)
    {
        try
        {
            #Call to GitHub 
            ###############################################################
            $ghResult=Invoke-WebRequest -Uri $uriNextCall -Headers $headers
            ###############################################################

            #Break loop by default
            $can_continue=$false
        
            if ($ghResult.StatusCode -ne "200")
            {
                throw New-Exception -InvalidOperation -Explanation "Call to GitHub URI $($uriNextCall) failed"
            }
            else
            {
                $paginationResults += $ghResult.Content

                #If we are able to pull all results at once, there will be no LINK header
                if ( $ghResult.Headers.ContainsKey("link") )
                {
                    $linksRaw=$ghResult.Headers.Link
                    $links=ConvertFrom-GHLinkHeader -LinkHeader $linksRaw
            
                    #$links | Out-Host #DEBUG
            
                    if ( $links.ContainsKey("next")  ) 
                    {
                        #More data to come
                        $can_continue=$true
                        $uriNextCall=$links["next"]
                    }
                }
         
            }    
        }
        catch
        {
            #we just rethrow the exception to avoid that the function continues running
            $exception = $_.Exception                        
            throw New-Exception -InvalidOperation -Explanation "Call to GitHub API failed - $($exception.Message)"
        }
    
    } # while loop


    return $paginationResults
}
