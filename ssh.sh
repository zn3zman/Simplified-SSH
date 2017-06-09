#!/bin/bash
#Poorly written by Will as a big learning experiment. Don't expect good code, practice, or syntax
#Debug? Set to -x for yes, +x for no 
set +x 
#Variables
Instances[0]=""

#Functions
GetInstances ()
{
  #Get instances and push output to a file
   aws ec2 describe-instances --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value,Distro:Tags[?Key==`Distro`].Value,Status:State.Name,PublicIP:NetworkInterfaces[].Association.PublicIp}' --output json> describe-instances
	
  #Create list header
  echo -e " # - InstanceID"   
  counter=1
  #Count instances in output to create array
  #Change this to query the exact information aws ec2 describe-instances --query 'Reservations[*].InstanceID
  for iID in `cat describe-instances | grep InstanceId | awk -F ": " '{print $2}' | tr -d '", '` ; do
    #Create number column from counter, add instanceID to instance array using counter, increment counter, create instanceID column
    if [[ "$counter" -lt "10" ]];then 
      echo -e -n " $counter - "
    else
      echo -e -n "$counter - "
    fi
    Instances[$counter]=$iID
    counter=$[counter+1]
    echo -e -n "$iID - "
    
    #InstanceID may for no reason suddenly not appear at the top of each information set. May need to adjust grep additional lines
    #Get Name tag using conviluted greps and awk.
    iNameTag=$(cat describe-instances | grep $iID -A 9|grep "Name" -A 1 | fgrep -v "[" | awk -F "\"" '{print $2}'| tr -d '",')
    echo -e -n "$iNameTag"
    
    #Get Distro tag using conviluted greps and awk
    iDistroTag=$(cat describe-instances | grep $iID -A 9|grep "Distro" -A 1 | fgrep -v "[" | awk -F "\"" '{print $2}'| tr -d '",')
    echo -e -n "\n\t\t\t   $iDistroTag - "
    
    #Get Status using conviluted greps and awk
    iStatus=$(cat describe-instances | grep $iID -A 9|grep "Status"| awk -F "\"" '{print $4}' | tr -d '",')
    echo -e -n "$iStatus"

    #Get PublicIP using conviluted greps and awk. If none (stopped), don't output anything
    iPublicIP=$(cat describe-instances | grep $iID -A 9|grep "PublicIP" -A 1 | fgrep -v "[" | awk -F "\"" '{print $2}'| tr -d '",')
    if [[ -n "$iPublicIP" ]];then echo -e -n " - $iPublicIP";fi

#    printf "%s - %s - %s - %s - %s\n" $counter $iID $iNameTag $iDistroTag $iStatus $iPublicIP

    #Done, new line
    echo -e ""
  done	
}

WhichInstance ()
{
  ValidInstance=0
  echo -e ""
  #Which instance? 
  while [[ true ]];do
    read -p "Which instance # would you like to SSH into? (q to quit) " SelectedInstance
    #echo "SelectedInstance: $SelectedInstance InstanceArrayCount: ${#Instances[@]}"
    #Is input an invalid character?
    if [[ "$SelectedInstance" == *['\!\,\.\'\-\=\/\\\{\}\[\]\<\>\?\;\:\'\"\~\`\@\#\$\|\%\^\&\*\(\)_+]* ]];then echo -e "\nInvalid option $SelectedInstance (Bad character)";continue;fi;
    #Is input bigger than the instace array size?
    if [[ "$SelectedInstance" -gt "${#Instances[@]}" ]];then echo -e "\nInvalid option $SelectedInstance (Bigger than instance array)";continue;fi
    #Did user enter q to quit? Before the less than zero check because q would trigger that
    if [[ "$SelectedInstance" == "q" ]];then echo -e "\nQuitting...";exit;fi
    #Is input less than or equal to 0?
    if [[ "$SelectedInstance" == "0" ]];then echo -e "\nInvalid option $SelectedInstance (Less than or equal to 0)";continue;fi
    #Contains letters?
    if [[ "$SelectedInstance" == *[!0-9]* ]];then echo -e "\nInvalid option $SelectedInstance (Not a number, not q)";continue
    else echo -e "\nA good choice, sir";break
    fi
  done
}

IsInstanceRunning ()
{
  #Using case and aws --query for status, start instance if stopped, loop until status is Running
  #Ignore if terminated?
  iID=${Instances[$SelectedInstance]}
  loopcount=1
  #Loop intil instance is in running status
  while [[ true ]];do
  aws ec2 describe-instances --instance-id "$iID" --query 'Reservations[*].Instances[*].{InstanceId:InstanceId,Name:Tags[?Key==`Name`].Value,Distro:Tags[?Key==`Distro`].Value,Status:State.Name,PublicIP:NetworkInterfaces[].Association.PublicIp}' --output json > describe-instances
    iStatus=$(cat describe-instances | grep $iID -A 9|grep "Status"| awk -F "\"" '{print $4}' | tr -d '",')
    echo -e -n "\nSelected instance is $iID and it's status is \"$iStatus\""
    case $iStatus in
      pending)
        echo -e -n "\nWaiting 10 seconds for the instance to start..."
        for i in {9..1};do sleep 1; echo -n "$i... ";done
        ;;
      running)
        iPublicIP=$(cat describe-instances | grep $iID -A 9|grep "PublicIP" -A 1 | fgrep -v "[" | awk -F "\"" '{print $2}'| tr -d '",')
        if [[ -n "$iPublicIP" ]];then
          echo -e -n "\nnc -zv $iPublicIP 22"
          nc -zv "$iPublicIP" 22
          if [[ "$?" -eq "0" ]];then echo -e "\nSSH is listening and we can say hi.";break
          else echo -e "Either the SSH daemon isn't running (yet?) or we can't reach the instance."
          echo -e -n "\nWaiting 10 seconds to try again..."
          for i in {9..1};do sleep 1; echo -n "$i... ";done
          fi
        else
          echo -e -n "\nNo public IP found for $iID. Is one assigned?"
          exit
        fi
        ;; 
      shutting-down)
        echo -e -n "\nWaiting 10 seconds for the instance to shut down..."
        for i in {9..1};do sleep 1; echo -n "$i... ";done
        ;;
      terminated)
        echo -e -n "\nNot much we can do about that :\'(" 
        exit
        ;;
      stopping)
        echo -e -n "\nWaiting 10 seconds for the instance to stop..."
        for i in {9..1};do sleep 1; echo -n "$i... ";done
        ;;
      stopped)
        aws ec2 start-instances --instance-ids "$iID"
        echo -e -n "\nStarting instance and waiting 10 seconds for the instance to stop..."
        for i in {9..1};do sleep 1;echo -n "$i... ";done
        ;;
      *)
        echo -e "Status "$iStatus" is not valid or something we planned for. Exiting..."
        exit
        ;;
    esac
    echo -e "\nAttempt $loopcount of 10"
    if [[ "$loopcount" -eq "10" ]];then echo -e "Well, we tried 10 times and failed. $iID's status is $iStatus. Exiting...";exit;fi
    loopcount=$[loopcount+1]
  done
}

StartSSH ()
{
  #Get Instance distro, test if 22 listening, then ssh using key pair from --query
  echo -e -n "\nLet's SSH"
  #Get keypair name
  iKeyName=$(aws ec2 describe-instances --instance-ids $iID --query 'Reservations[*].Instances[*].{KeyName1:KeyName}' | awk -F "\"" '{print $2}'| tr -d '",')
  if [[ -n "$iKeyName" ]];then echo -e -n "Eh, doesn't look like there's a key pair name associated. Exiting...";exit
  else echo -e -n "Connecting to $iID with $iKeyname.pem"
  fi
  #Connect using the keypair if it exists in the current directory
  if [[ !  -f "$iKeyName.pem" ]];then
  echo -e "$iKeyPair.pem doesn't exist in $(pwd). Exiting...";exit
  fi
  #Get distro from Distro tag
  iDistroTag=$(cat describe-instances | grep $iID -A 9|grep "Distro" -A 1 | fgrep -v "[" | awk -F "\"" '{print $2}'| tr -d '",')
  case $iDistroTag in
    Amzn*|RHEL*|Cent*)
      sshuser=ec2-user;;
  ssh -v -i "$iKeyPair.pem" $sshuser@$iPublicIP 
  
  
}
#Populate Instance list
GetInstances
#Ask which instance to SSH into
WhichInstance
#Check if the instance is running
IsInstanceRunning
#SSH into the selected instance
StartSSH

#For testing
#echo -e "${Instances[*]}"
