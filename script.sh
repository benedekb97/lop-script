#!/bin/bash
# 
# 
# Steals a database from one of Straxus' development servers or Production servers
# and imports it to your mysql server.
# 
# 
# ------------ Before using please read this description ------------
# 
# Installation:
# 1. Set up the configuration
# 2. Start stealing databases
#
# Arguments:
# 	-e --env [env]	specify the environment to steal from (dev/staging/prod)
# 	-s --src <sourceDBName>				specify the name of the source DB
#   -t --target <targetDBName>			specify the name of the target DB
#   -h --help           help shit
#   --no-colors   Doesn't display colors
 
######################################
########## START OF CONFIG ##########
######################################

# SSH hosts (~/.ssh/config)
devHost=""
stagingHost=""
prodHost=""

# DB
# dev
devDBHost="" # mysql host
devDBUser="" # mysql user
devDBPass="" # mysql password
devDBPort="3306"  # mysql port
devDBDefaultName="" # default DB to steal if none specified

# staging
stagingDBHost=""
stagingDBUser=""
stagingDBPass=""
stagingDBPort="3306"
stagingDBDefaultName=""

# prod
prodDBHost=""
prodDBUser=""
prodDBPass=""
prodDBPort="3306"
prodDBDefaultName=""

# local settings
dbHost=""  # default 127.0.0.1
dbUser=""  # default root
dbPass=""  # default rootpw
dbPort=""  # default 3306

# defaults
colors="true"
defaultEnv="dev"

######################################
########### END OF CONFIG ###########
######################################

# Written by Benedek Burgess for Straxus Kft.
# 2020-11-26



# defaults
srcDBName=""
env=""
targetDBName=""

# check local DB connection
if [ "$dbPass" = "" ]
then
	dbPass="rootpw"
fi

if [ "$dbUser" = "" ]
then
	dbUser="root"
fi

if [ "$dbHost" = "" ]
then
	dbHost="127.0.0.1"
fi

if [ "$dbPort" = "" ]
then
	dbPort="3306"
fi

testLocalDB=$(mysql -u$dbUser -h$dbHost -p$dbPass -P$dbPort -e"quit" 2>&1)
mysqlPasswordCommandLineWarning="mysql: [Warning] Using a password on the command line interface can be insecure."

if [ "$testLocalDB" != "$mysqlPasswordCommandLineWarning" ]
then
	echo "${RED}Local database connection failed with error message:${NC}"
	echo "$testLocalDB"
	echo ""
	echo "${YELLOW}Should probably set up your local database configuration :)${NC}"
	exit 1
fi

env="dev"
srcDBName=""
targetDBName=""
force="0"

for arg in "$@"
do
	case $arg in
		-f|--force)
			force="1"
			shift
			;;
		-e|--env)
		  if [ "$2" = "" ]
		  then
		    echo "${RED}Invalid argument supplied after '$1'${NC}"
		    exit 1;
      fi
			env="$2"
			shift
			shift
			;;
		-s|--src|--source)
		  if [ "$2" = "" ]
		  then
		    echo "${RED}"
      fi
			srcDBName="$2"
			shift
			shift
			;;
		-t|--target)
			targetDBName="$2"
			shift
			shift
			;;
	  --no-colors)
	    colors="false"
	    shift;
	    ;;
		-h|--help)
			echo "Ezzel tudsz DB-t lopni dev/staging/prod-ról"
			echo ""
			echo "Kapcsolók:"
			echo "-e --env [dev/staging/prod] 		Válassz a három lehetőség közül (előtte töltsd ki a configot)"
			echo "-s --src --source [sourceDBName] 	Mi a neve az eredeti DB-nek (pl. prodon van aeron, monotik, stb.)"
			echo "-t --target [targetDBName] 		Mi legyen a neve az új DB-nek amit felhúz saját gében"
			echo "--no-colors       			Ha buzi vagy akkor használd"
			echo "-h --help 				Ez a szar amit most látsz"
			echo ""
			echo ""
			echo "Ha valami szar akkor nézd át a configot (ennek a fájlnak az eleje, szépen meg van jelölve) illetve az ssh configodat (~/.ssh/config)"
			echo ""
			echo "Jó lopást!"
			exit 0;
			;;
	esac
done

if [ "$colors" = "true" ]
then
  RED='\033[0;31m'
  GREEN='\033[0;32m'
  YELLOW='\033[1;33m'
  NC='\033[0m'
else
  RED='\033[0m'
  GREEN='\033[0m'
  YELLOW='\033[0m'
  NC='\033[0m'
fi

# set source database information
if [ "$env" = "dev" ]; then
	if [ "$srcDBName" = "" ]; then
		srcDBName="$devDBDefaultName"
	fi
	srcHost="$devHost"
	srcDBHost="$devDBHost"
	srcDBUser="$devDBUser"
	srcDBPort="$devDBPort"
	srcDBPass="$devDBPass"
else 
	if [ "$env" = "staging" ]; then
		if [ "$srcDBName" = "" ]; then
			srcDBName="$stagingDBDefaultName"
		fi
		srcHost="$stagingHost"
		srcDBHost="$stagingDBHost"
		srcDBUser="$stagingDBUser"
		srcDBPort="$stagingDBPort"
		srcDBPass="$stagingDBPass"
	else 
		if [ "$env" = "prod" ]; then
			if [ "$srcDBName" = "" ]; then
				srcDBName="$prodDBDefaultName"
			fi
			srcHost="$devHost"
			srcDBHost="$devDBHost"
			srcDBUser="$devDBUser"
			srcDBPort="$devDBPort"
			srcDBPass="$devDBPass"
		else
			env="$defaultEnv"
			echo "No environment specified! Using $defaultEnv as default!"
			if [ "$srcDBName" = "" ]; then
				srcDBName="$devDBDefaultName"
			fi
			srcHost="${$defaultEnv"Host"}"
			srcDBHost="${$defaultEnv"DBHost"}"
			srcDBUser="${$defaultEnv"DBUser"}"
			srcDBPort="${$defaultEnv"DBPort"}"
			srcDBPass="${$defaultEnv"DBPass"}"
		fi
	fi
fi

# if target DB name is not set use default value
if [ "$targetDBName" = "" ]; then
	targetDBName="monotik_"$env"_"$(date +"%Y_%m_%d")
	echo "No target database name supplied! Using ${GREEN}$targetDBName${NC} as default."
	echo ""
fi

# check local mysql server for database with same name
findDatabaseWithSameName=$(mysql -u$dbUser -h$dbHost -p$dbPass -P$dbPort -e"USE $targetDBName" 2>&1)

# if returns only with password error then it exists
if [ "$findDatabaseWithSameName" = "$mysqlPasswordCommandLineWarning" ]
then
	if [ "$force" = "1" ]
	then
	  echo "Database named ${YELLOW}$targetDBName${NC} already exists! Dropping!"
		deleteExistingDatabase=$(mysql -u$dbUser -h$dbHost -p$dbPass -P$dbPort -e"DROP DATABASE $targetDBName;" 2>&1)
		if [ "$deleteExistingDatabase" != "$mysqlPasswordCommandLineWarning" ]
		then
      echo "${RED}Failed to delete existing database!${NC}"
      echo "$deleteExistingDatabase"
      echo ""
      echo "Aborting..."
      exit 0;
    fi
	else
		echo "Database named ${RED}$targetDBName${NC} already exists !"
		echo "Use -f|--force to force"
		exit 1;
	fi
fi

# set filename for stolen DB
filename="."$targetDBName".sql"

# Dump source database to file
echo "${GREEN}Dumping source database to file: ${NC}$filename (This could take a while)"
dumpSourceDB=$(ssh $srcHost mysqldump -u$srcDBUser -h$srcDBHost -p"$srcDBPass" -P$srcDBPort --lock-tables=false --single-transaction --quick $srcDBName > $filename 2>&1)
echo "Database dump ${GREEN}successful${NC}!"
echo ""

# Create target database
echo "${GREEN}Creating target database ${NC}$targetDBName"
createTargetDB=$(mysql -h$dbHost -P$dbPort -p$dbPass -u$dbUser -e"CREATE DATABASE $targetDBName;" 2>&1)
if [ "$createTargetDB" != "$mysqlPasswordCommandLineWarning" ]
then
	echo "${RED}Failed to create target database!${NC}"
	echo "$createTargetDB"
	
	echo "Aborting..."
	rm $filename
	exit 1;
else
	echo "Target database created ${GREEN}successfully${NC}!"
	echo ""
fi

# Import the database
echo "Importing database! (This could take a while)"
importTargetDB=$(mysql -h$dbHost -P$dbPort -p$dbPass -u$dbUser $targetDBName < $filename 2>&1)
if [ "$importTargetDB" != "$mysqlPasswordCommandLineWarning" ]
then 
	echo "${RED}Failed to import target database!${NC}"
	echo "$importTargetDB"
	
	echo "Aborting..."
	rm $filename
	exit 1;
else
	echo "Target database improted ${GREEN}successfully${NC}!"
	echo ""
fi

# Clear all the shit
echo "Cleaning the database!"
updateSellerHostname=$(mysql -h$dbHost -P$dbPort -p$dbPass -u$dbUser -e"USE $targetDBName; UPDATE seller SET hostname='api.monotik.local' WHERE id = 1;" 2>&1)
addChannelHost=$(mysql -h$dbHost -P$dbPort -p$dbPass -u$dbUser -e"USE $targetDBName; INSERT INTO channel_host ('channel_id', 'hostname', 'enabled', 'created_at', 'public_hostname') values ('1', 'api.monotik.local', '1', '2020-11-26 21:08:33', 'localhost:3001');" 2>&1)
removeEncryptedConfiguration=$(mysql -h$dbHost -P$dbPort -p$dbPass -u$dbUser -e"USE $targetDBName; UPDATE shipping_gateway SET encrypted_configuration=NULL;" 2>&1)

# echo any errors
if [ "$updateSellerHostname" != "$mysqlPasswordCommandLineWarning" ]
then
	echo "${RED}Seller hostname update failed!${NC}"
	echo "$updateSellerHostname"
	echo ""
	shouldExit="true"
fi

if [ "$addChannelHost" != "$mysqlPasswordCommandLineWarning" ]
then
	echo "${RED}Failed to add channel host!${NC}"
	echo "$addChannelHost"
	echo ""
	shouldExit="true"
fi

if [ "$removeEncryptedConfiguration" != "$mysqlPasswordCommandLineWarning" ]
then
	echo "${RED}Failed to remove encrypted configurations${NC}"
	echo "$removeEncryptedConfiguration"
	echo ""
	shouldExit="true"
fi

if [ "$shouldExit" = "true" ]
then
	rm $filename
	echo "Aborting..."
	exit 1;
fi

# remove useless exported .sql file
echo "Cleaning up!"
echo ""
rm $filename

# yolo swag you stole a DB
echo "Database imported successfully! (or not, nem csináltam még error handlinget)"
echo "${YELLOW}Don't forget php bin/console do:mi:mi"
exit 0;