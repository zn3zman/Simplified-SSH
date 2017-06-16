#!/bin/bash
#Poorly written by Will as a big learning experiment. Don't expect good code, practice, or syntax
#Debug? Set to -x for yes, +x for no 
set +x 
#Variables
red=$(tput setaf 1)
green=$(tput setaf 2)
yellow=$(tput setaf 3)
cyan=$(tput setaf 6)
nocolor=$(tput sgr0)
Regions[0]=""
Instances[0]=""
InstancesRegions[0]=""

#Functions
ListRegions () {
  #Unset and recreate Regions array to reset for a second loop through
  unset Regions; Regions[0]="";echo ""
  #Describe-regions, output to a file, and sort for readability
  aws ec2 describe-regions --output text --query 'Regions[].{Name:RegionName}' > describe-regions
  sort describe-regions -o describe-regions
  #Set loop/array counter to 1 and print table headers
  counter=1
  printf '=%.0s' {1..57} 
  #The color changing variable counts toward the character count of the coloumn header it's touching
  printf "\n| %2s - %-15s - %-36s |\n" ${cyan}" #" "Region Name" "Region Location"${nocolor}
  #Loop through the describe-regions output file, adding a Friendly Name for each region
  for iRegion in $(cat describe-regions) ; do
    Regions[$counter]=$iRegion
    case $iRegion in
      ap-south-1)
      iRegionFriendly="Asia Pacific (Mumbai)";;
      eu-west-2)
      iRegionFriendly="EU (London)";;
      eu-west-1)
      iRegionFriendly="EU (Ireland)";;
      ap-northeast-2)
      iRegionFriendly="Asia Pacific (Seoul)";;
      ap-northeast-1)
      iRegionFriendly="Asia Pacific (Tokyo)";;
      sa-east-1)
      iRegionFriendly="South America (Sao Paulo)";;
      ca-central-1)
      iRegionFriendly="Canada (Central)";;
      ap-southeast-1)
      iRegionFriendly="Asia Pacific (Singapore)";;
      ap-southeast-2)
      iRegionFriendly="Asia Pacific (Sydney)";;
      eu-central-1)
      iRegionFriendly="EU (Frankfurt)";;
      us-east-1)
      iRegionFriendly="US East (N. Virginia)";;
      us-east-2)
      iRegionFriendly="US East (Ohio)";;
      us-west-1)
      iRegionFriendly="US West (N. California)";;
      us-west-2)
      iRegionFriendly="US West (Oregon)";;
      *)
      iRegionFriendly="A newly added region";; 
    esac
	#Print selection number, region name, and region friendly name, then increase counter and continue loop
    printf "| %2s | %-15s | %-30s |\n" $counter $iRegion "$iRegionFriendly"
    counter=$[counter+1]
  done
  #Print footer
  printf '=%.0s' {1..57}
}

GetiRegion () {
  #Get the AZ of the instance from the describe-instances output, then remove the trailing AZ identifier to leave just the region
  local iRegion="$(sed -n -e "/$iID/,/AAINSTANCE/ p" describe-instances | grep -m 1 -i "AvailabilityZone" | awk -F " " '{print $2}')"
  if [[ -z "$iRegion" ]]; then iRegion="Error"; fi
  echo "${iRegion::-1}"
}

GetiNameTag () {
  #Get the Name tag of the instance from the describe-instances output
  local iNameTag="$(sed -n -e "/$iID/,/AAINSTANCE/ p" describe-instances | grep -m 1 -i "Name" | awk -F " " '{print $2}')"
  if [[ -z "$iNameTag" ]]; then iNameTag="None"; fi
  echo "$iNameTag"
}

GetiImageID () {
  #Get the ImageID (AMI) of the instance from the describe-instances output
  local iImageID="$(sed -n -e "/$iID/,/AAINSTANCE/ p" describe-instances | grep -m 1 -i "ImageID" | awk -F " " '{print $2}')"
  if [[ -z "$iImageID" ]]; then iImageID="None"; fi
  echo "$iImageID"
}

GetiDistroTag () {
  #Get the Distro tag of the instance from the describe-instances output, if set. 
  local iDistroTag=$(sed -n -e "/$iID/,/AAINSTANCE/ p" describe-instances | grep -m 1 -i "Distro" | awk -F " " '{print $2}')
  #if [[ "$iDistroTag" == "Win"* ]]; then iDistroTag="${red}$iDistroTag${nocolor}"; fi
  #If the Distro tag is not set/doesn't exist, describe-images on the instance's ImageID and guess based on the name and description of the AMI
  if [[ -z "$iDistroTag" ]]; then 
    aws ec2 describe-images --image-ids $(GetiImageID) --region $(GetiRegion) --output text --query '{ImageName:Images[*].Name,ImageDescription:Images[*].Description}' > describe-images
    for i in $(cat describe-images); do
      if [[ $(echo $i | grep -i "Centos\|Cent OS") ]] ; then iDistroTag="CentOS"; break; fi
      if [[ $(echo $i | grep -i "Red hat\|Redhat\|RHEL") ]] ; then iDistroTag="RHEL"; break; fi
      if [[ $(echo $i | grep -i "Ubuntu") ]] ; then iDistroTag="Ubuntu"; break; fi
      if [[ $(echo $i | grep -i "Bitnami") ]] ; then iDistroTag="Bitnami"; break; fi
      if [[ $(echo $i | grep -i "Amazon\|Amzn") ]] ; then iDistroTag="AmznLinux"; break; fi
	  #If the AMI name or description don't match any of the above, set iDistroTag to Unknown
      iDistroTag="Unknown"
    done
  fi
  echo "$iDistroTag"
}

GetiStatus () {
  #Get the status of the instance from the describe-instances output
  local iStatus="$(sed -n -e "/$iID/,/AAINSTANCE/ p" describe-instances | grep -m 1 -i "Status"| awk -F " " '{print $2}')"
  #if [[ -z "$iStatus" ]]; then iStatus="Unknown"; fi
  echo "$iStatus"
}

GetiPublicIP () {
  #Get the public IP of the instance from the describe-instances output, if there is one
  local iPublicIP="$(sed -n -e "/$iID/,/AAINSTANCE/ p" describe-instances | grep -m 1 -i "PublicIP" | awk -F " " '{print $2}')"
  if [[ -z "$iPublicIP" ]]; then iPublicIP="None"; fi
  echo "$iPublicIP"
}

GetiKeyName () {
  #Get the name of the key pair used in the launch of the instance from the describe-instances output
  local iKeyName="$(aws ec2 describe-instances --output text --region $(GetiRegion) --instance-ids $iID --query 'Reservations[*].Instances[*].{KeyName1:KeyName}')"
  #echo $(GetiRegion) >> test
  if [[ -z "$iKeyName" ]]; then iKeyName="None"; fi
  echo "$iKeyName"
}

ListInstances () {
  #Reset Instances array in case this is the second time through the function and set loop/array counter to 1 and . 
  unset Instances; Instances[0]="";unset InstancesRegions; InstancesRegions[0]=""; counter=1; echo ""
  #Remove the describe-instanes file if it exists
  if [[ -f "./describe-instances" ]]; then rm -f "./describe-instances" > /dev/null; fi
  #Loop through the Regions array using TempRegion as the loop variable to list all regions. Array will only contain one region if the user only selected one reason
  for TempRegion in ${Regions[@]}; do
    #Get instances and needed data from huge CLI query and push output to a a describe-instances file in this directory
    aws ec2 describe-instances --region $TempRegion --output text --query 'Reservations[*].{AAInstanceID:Instances[*].InstanceId,Name:Instances[*].Tags[?Key==`Name`].Value,Distro:Instances[*].Tags[?Key==`Distro`].Value,Status:Instances[*].State.Name,PublicIP:Instances[*].NetworkInterfaces[].Association.PublicIp,AvailabilityZone:Instances[*].Placement.AvailabilityZone,ImageID:Instances[*].ImageId}' > describe-instances
    #unset iID in case this is the second loop through the function
	unset iID
	#Loop through the describe-instances file with the instance ID as the loop variable
    for iID in $(cat describe-instances | grep -i InstanceId | awk -F " " '{print $2}') ; do
	  #Create the table header if the loop counter is 1
      if [[ $counter == "1" ]]; then
        printf '=%.0s' {1..130}
        printf "\n| %2s - %-15s - %-19s - %-25s - %-20s - %-12s - %-21s |\n" ${cyan}" #" "Region" "InstanceID" "Name" "Distro" "Status" "Public IP"${nocolor}
      fi
      #Add instanceID to instance array using counter
      Instances[$counter]=$iID
      #Populate iRegion with the output of the GetiRegion function
	  iRegion=$(GetiRegion)
	  InstancesRegions[$counter]=$iRegion
      #Populate iNameTag with the output of the GetiNameTag function
      iNameTag=$(GetiNameTag)
      #Populate iDistroTag with the output of the GetiDistroTag function
      iDistroTag=$(GetiDistroTag)
      #Populate iStatus with the output of the GetiStatus function
      iStatus=$(GetiStatus)
      #Populate iPublicIP from the output of the GetiPublicIP function
      iPublicIP=$(GetiPublicIP)
	  #Print instance variables to table and increment loop counter by 1
      printf "| %2d | %-15s | %-19s | %-25s | %-20s | %-12s | %-15s |\n" $counter $iRegion $iID $iNameTag $iDistroTag $iStatus $iPublicIP
      counter=$[counter+1]
    done
  done
  #Print table footer if the iID variable is not empty. This keeps the footer from being printed when listing a region without instances
  if [[ ! -z "$iID" ]]; then printf '=%.0s' {1..130}; fi
}

WhichRegion () {
  while [[ true ]]; do
    echo -e ""
    read -p "Which region # would you like to list instances for? You can also type ${yellow}all${nocolor} to list all and ${yellow}q${nocolor} to quit: " SelectedRegion
    if [[ "$SelectedRegion" == *['\!\,\.\'\-\=\/\\\{\}\[\]\<\>\?\;\:\'\"\~\`\@\#\$\|\%\^\&\*\(\)_+]* ]];then echo -e "\nInvalid option $SelectedRegion (Bad character)";continue;fi;
    if [[ -z "$SelectedRegion" ]]; then echo -e "${red}\nPlease choose a region by typing the number listed for that row${nocolor}"; continue; fi
    if [[ "$SelectedRegion" == "all" ]]; then echo -e "\nListing instances for all regions (this may take a few moments):"; break; fi;
    if [[ "$SelectedRegion" -gt "$((${#Regions[@]}-1))" ]];then echo -e "\nInvalid option $SelectedRegion (Bigger than region array)";continue;fi
    if [[ "$SelectedRegion" == "q" ]];then echo -e "\nQuitting..."; CleanExit;fi
    #Is input less than or equal to 0?
    if [[ "$SelectedRegion" == "0" ]];then echo -e "\nInvalid option $SelectedRegion (Less than or equal to 0)";continue;fi
    #Contains letters?
    if [[ "$SelectedRegion" == *[!0-9]* ]];then echo -e "\nInvalid option $SelectedRegion (Not a number, not ${yellow}q${nocolor} or ${yellow}all${nocolor})";continue
    else
	  #If one region is selected, set iRegion to it and clear the Regions array to only contain the selected region
      iRegion="${Regions[$SelectedRegion]}"
      unset Regions; Regions[0]="$iRegion" 
      break
    fi
  done
}

WhichInstance () {
  #Which instance? 
  while [[ true ]]; do
    if [[ "${Instances[1]}" == "" ]]; then echo -e "\n${red}No instances found in this region.${nocolor}"; main; fi
    echo ""
    read -p "Which instance # would you like to SSH into? (${yellow}q${nocolor} to quit) " SelectedInstance
    #echo "SelectedInstance: $SelectedInstance InstanceArrayCount: ${#Instances[@]}"
    #Is input an invalid character?
    if [[ "$SelectedInstance" == *['\!\,\.\'\-\=\/\\\{\}\[\]\<\>\?\;\:\'\"\~\`\@\#\$\|\%\^\&\*\(\)_+]* ]];then echo -e "\nInvalid option $SelectedInstance (Bad character)";continue;fi;
    if [[ -z "$SelectedInstance" ]]; then echo -e "${red}\nPlease choose an instance by typing the number listed for that row${nocolor}"; continue; fi
    #Is input bigger than the instace array size?
    if [[ "$SelectedInstance" -gt "$((${#Instances[@]}-1))" ]];then echo -e "\nInvalid option $SelectedInstance (Bigger than instance array)";continue;fi
    #Did user enter q to quit? Before the less than zero check because q would trigger that
    if [[ "$SelectedInstance" == "q" ]];then echo -e "\nQuitting..."; CleanExit;fi
    #Is input less than or equal to 0?
    if [[ "$SelectedInstance" == "0" ]];then echo -e "\nInvalid option $SelectedInstance (Less than or equal to 0)";continue;fi
    #Contains letters?
    if [[ "$SelectedInstance" == *[!0-9]* ]];then echo -e "\nInvalid option $SelectedInstance (Not a number, not ${yellow}q${nocolor})";continue
    else 
      iID=${Instances[$SelectedInstance]}
	  iRegion=${InstancesRegions[$SelectedInstance]}
      break
    fi
  done
}

IsInstanceRunning () {
  #Using case and aws --query for status, start instance if stopped, loop until status is Running
  counter=1
  #Loop intil instance is in running status
  while [[ true ]]; do
    aws ec2 describe-instances --region $iRegion --output text --query 'Reservations[*].{AAInstanceID:Instances[*].InstanceId,Name:Instances[*].Tags[?Key==`Name`].Value,Distro:Instances[*].Tags[?Key==`Distro`].Value,Status:Instances[*].State.Name,PublicIP:Instances[*].NetworkInterfaces[].Association.PublicIp,AvailabilityZone:Instances[*].Placement.AvailabilityZone,ImageID:Instances[*].ImageId}' --filter Name=instance-id,Values="$iID" > describe-instances
    iStatus=$(GetiStatus)
    echo -e "\nSelected instance is $iID and it's status is \"$iStatus\""
    case $iStatus in
      pending)
        echo -e -n "\nWaiting 10 seconds for the instance to start... "
        for i in {9..1};do sleep 1; echo -n "$i... ";done
        ;;
      running)
        iPublicIP=$(GetiPublicIP)
        if [[ -n "$iPublicIP" ]]; then
          echo -e "\n$ nc -zv $iPublicIP 22"
          nc -zv "$iPublicIP" 22
          if [[ "$?" -eq "0" ]]; then 
            echo -e "\nSSH daemon is running and is listening on port 22.";break
          else 
            echo -e "Either the SSH daemon isn't running (yet?) or we can't reach the instance."
          echo -e -n "\nWaiting 10 seconds to try again... "
          for i in {9..1};do sleep 1; echo -n "$i... ";done
          fi
        else
          echo -e "\nNo public IP found for $iID. Is one assigned?"
          main
        fi
        ;; 
      shutting-down)
        echo -e -n "\nWaiting 10 seconds for the instance to shut down... "
        for i in {9..1};do sleep 1; echo -n "$i... ";done
        ;;
      terminated)
        echo -e "$iID is terminated."
        echo -e "\nNot much we can do about that :\'(" 
        main
        ;;
      stopping)
        echo -e -n "\nWaiting 10 seconds for the instance to stop... "
        for i in {9..1};do sleep 1; echo -n "$i... ";done
        ;;
      stopped)
        echo -e "Starting $iID..."
        echo -e "$ aws ec2 start-instances --instance-ids $iID --region $(GetiRegion)"
        aws ec2 start-instances --instance-ids "$iID" --region $(GetiRegion)
        echo -e -n "\nStarting instance and waiting 10 seconds for the instance to start... "
        for i in {9..1};do sleep 1;echo -n "$i... ";done
        ;;
      *)
        echo -e "Status "$iStatus" is not valid or something we planned for. Exiting..."
        main 
        ;;
    esac
    echo -e "\nAttempt $counter of 10"
    if [[ "$counter" -eq "10" ]];then echo -e "Well, we tried 10 times and failed. $iID's status is $iStatus. Exiting..."; main;fi
    counter=$[counter+1]
  done
}

StartSSH () {
  #Get Instance distro, test if 22 listening, then ssh using key pair from --query
  #Get keypair name
  iKeyName="$(GetiKeyName)"
  if [[ -z "$iKeyName" ]]; then 
    echo -e "Eh, doesn't look like there isn't a key pair name associated. Exiting...\n"; main
  else echo -e "$iID is associated with $iKeyName.pem"
  fi
  #Connect using the keypair if it exists in the current directory
  if [[ ! -f "$HOME/$iKeyName.pem" ]]; then
    echo -e "$iKeyName.pem doesn't exist in \"$HOME\". Searching your home directory for it..."
    #Search user's home directory for $iKeyName.pem, grepping out errors, then take the result and grab the path without the filename
    iKeyDir="$(dirname $(find ~ -name $iKeyName.pem 2>&1 | grep -vi "denied\|error"))"
    if [[ -z "$iKeyDir" ]] ; then echo -e "Couldn't find $iKeyName.pem Exiting...\n"; main; fi
  else
    iKeyDir="$HOME" 
    echo -e "Found $iKeyDir/$iKeyName.pem"
  fi
  #Get distro from Distro tag
  echo -e -n "Checking distro for $iID... "
  iDistroTag=$(GetiDistroTag)
  case $iDistroTag in
    Amzn*|Amazon*|RHEL*)
      iSSHUser="ec2-user";;
    Cent*|Red*)
      iSSHUser="centos";;
    Ubuntu*)
      iSSHUser="ubuntu";;
    Win*)
      echo -e "This might be a Windows instance. If you'd still like to attempt ssh:";;
    *)
      echo -e "Couldn't figure out the distro, either because the instance doesn't have a Distro tag or the syntax was not expected.\nDefaulting to \"ec2-user\" for the user name."
      iSSHUser="ec2-user";;
  esac
  echo -e -n "best guess is $iDistroTag\n"
  read -p "What user would you like to SSH as? Leave blank (just press enter) to use the default \"$iSSHUser\": " iCustomSSHUser
  if [[ ! -z "$iCustomSSHUser" ]]; then
    #echo -e "Using \"$iCustomSSHUser\" as the user instead of \"$iSSHUser\"."
    iSSHUser="$iCustomSSHUser"
  fi
  echo -e "Connecting to $iID as \"$iSSHUser\" using private key \"$iKeyDir/$iKeyName.pem\""
  echo -e "Type ${yellow}exit${nocolor} to end the SSH session."
  echo -e "$ ssh -i \"$iKeyDir/$iKeyName.pem\" $iSSHUser@$iPublicIP -o \"ServerAliveInterval 30\""
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  ssh -i "$iKeyDir/$iKeyName.pem" $iSSHUser@$iPublicIP -o "ServerAliveInterval 30"
  printf '%*s\n' "${COLUMNS:-$(tput cols)}" '' | tr ' ' -
  
}

StopInstance () {
  #Stop the instance after being used, if desired.
  while true ; do
    echo -e ""
    read -p "Would you like to stop that instance, $iID? (y/n) " StopTheInstance
    case $StopTheInstance in
    [yY])
      echo -e "$ aws ec2 stop-instances --instance-ids $iID --region $(GetiRegion)"
      aws ec2 stop-instances --instance-ids "$iID" --region $(GetiRegion)
      echo -e "\nCommand sent to stop instance $iID"
      break
      ;;
    [nN])
      break
      ;;
    *)
      echo -e "${red}Please type either 'y' or 'n'${nocolor}"
      ;;
    esac
  done
}

CleanExit () {
if [[ -f "./describe-regions" ]]; then rm -f "./describe-regions" > /dev/null; fi
if [[ -f "./describe-instances" ]]; then rm -f "./describe-instances" > /dev/null; fi
if [[ -f "./describe-images" ]]; then rm -f "./describe-images" > /dev/null; fi
echo -e "${green}Thanks for using simplified-ssh!${nocolor}"
exit 0
}

main () {
while true; do
  #Get Region List
  ListRegions
  #Ask which region to select
  WhichRegion
  #Populate Instance list
  ListInstances
  #Ask which instance to SSH into
  WhichInstance
  #Check if the instance is running
  IsInstanceRunning
  #SSH into the selected instance
  StartSSH
  #Stop the targeted instance, if desired
  StopInstance
done
}

main "$@"
