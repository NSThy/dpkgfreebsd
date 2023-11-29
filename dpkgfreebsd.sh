#!/bin/sh

# ignore all deb pip linux dependencies
force=0
# if any linux c7 requirements are not satisfied,will set to 1
linux_status_failed=0
# if linux c7 requirements are all checked and ok,will set to 1 to avoid repeat check in the future
linux_checked=0

# Define ANSI color codes and different echo style
RED='\033[1;31m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
BLUE='\033[1;34m'
RESET_COLOR='\033[0m'
echo_warning() {
  echo -e "${RED}Warning: $1${RESET_COLOR}"
}
echo_success() {
  echo -e "${GREEN}Success: $1${RESET_COLOR}"
}
echo_running() {
  echo -e "${BLUE}Running: $1${RESET_COLOR}"
}
echo_information() {
  echo -e "${YELLOW}Information: $1${RESET_COLOR}"
}

# Check if the script is running with sudo
echo_running "Checking root permission"
if [ "$(id -u)" -ne 0 ]; then
    	echo_warning "Failed! this script requires superuser privileges. Please run with sudo."
    	exit 1
else
	echo_success "Root permission is granted"
fi

# Check if force is enabled
if [ "$1" = "-f" ]; then
	force=1
    	shift 
fi

# Check if there is a file input
if [ "$#" -eq 0 ]; then
	echo -e "${YELLOW}A small tool to fix dependencies and install deb correctlly,created by nsthy${RESET_COLOR}"
    	echo -e "${YELLOW}Usage: 	$0 <inputfile1.deb> <inputfile2.deb> <inputfile3.deb>... ${RESET_COLOR}"
    	echo -e "${YELLOW}Option:	-f	ignore dependencies${RESET_COLOR}"
    	echo_information "Freebsd's pkg system is difficult to use,but Debian's deb system is easy to use,so i found a way to combine them together
    	install a deb package also fix the dependencies,i am not a programmer,most codes are made by chatgpt,i am surprised that get this so far
    	here is some rules about creating a freebsd deb package
    	DEBIAN/control
    	Depends: example1, example2, example3 # exact dependencies of freebsd packages
    	Pydeps: example1, example2, example3 # some python packages are not in official freebsd repos,so will use pip to install the dependencies
    	Architecture: freebsd-amd64 #identify it is a freebsd base deb file,also can stop another linux system from installing it
    	
    	for linux c7 package,please name like this,so i can know and check if the linux-c7 is setup correctlly
    	linux-c7-example1
    	linux-c7-example2
    	linux-c7-example3
    	
    	"
    	echo_warning "No files input,stopping..." 
    	exit 1
fi

# Check if dpkg is installed
echo_running "Checking is package <dpkg> installed"
pkg info dpkg >/dev/null 2>&1
if [ $? -eq 0 ]; then
	echo_success "Package <dpkg> is installed."
else
	echo_warning "Package <dpkg> is not installed. Now installing it"
	pkg install -y dpkg
        if [ $? -eq 0 ]; then
    		echo_success "Package <dpkg> was installed successfully"
	else
    		echo_warning "Package <dpkg> installation failed,stopping..."
   	 	exit 1
	fi
fi

# Check dpkg runtime,freebsd default install dpkg missing the file /var/db/dpkg/status
echo_running "Checking dpkg runtime"
if [ ! -d "/var/db/dpkg" ]; then
	echo_warning "Missing folder: /var/db/dpkg,creating it"
  	mkdir -p /var/db/dpkg
  	if [ $? -eq 0 ]; then
   		echo_success "Create a folder successfully"
   	else
   		echo_warning "Failed to create a folder /var/db/dpkg,stopping..."
   	 	exit 1
   	fi
fi
if [ ! -f "/var/db/dpkg/status" ]; then
	echo_warning "Missing file: /var/db/dpkg/status,creating it"
   	touch /var/db/dpkg/status
   	if [ $? -eq 0 ]; then
   		echo_success "Create a file successfully"
   	else
   		echo_warning "Failed to create a file /var/db/dpkg/status,stopping..."
   	 	exit 1
   	fi
else
	echo_success "dpkg runtime is ok"
fi

# Check if pip installed
echo_running "Checking is package <pip> installed"
pkg info py39-pip >/dev/null 2>&1
if [ $? -eq 0 ]; then
	echo_success "Package <pip> is installed."
else
	echo_warning "Package <pip> is not installed. Now installing it"
	pkg install -y py39-pip
        if [ $? -eq 0 ]; then
    		echo_success "Package <pip> was installed successfully"
	else
    		echo_warning "Package <pip> installation failed,stopping..."
   	 	exit 1
	fi
fi

# Update icon cache
update_icon_cache() {
    	if [ "$(uname)" = "FreeBSD" ]; then
    		echo -e "${GREEN}"
		gtk-update-icon-cache -f /usr/local/share/icons/hicolor/
		echo -e "${RESET_COLOR}"
	elif [ "$(uname)" = "Linux" ]; then
		echo -e "${GREEN}"
		gtk-update-icon-cache -f /usr/share/icons/hicolor/
		echo -e "${RESET_COLOR}"
	else
  	  	echo_warning "Unsupported operating system,so the icon cache is not updated"
	fi
}

# Core funtion,check and install deb pip dependencies
fix_deb_depends() {
    	# read dependencies from deb
    	deb_file="$1"
    	missing_packages=""
    	depends=$(dpkg-deb -I "$deb_file" | grep -E 'Depends' | sed 's/Depends://g' | tr -d '[:space:]')    
    	depends_spaced=$(echo "$depends" | tr ',' ' ')

    	# check which deb depend is not installed
    	echo_running "Checking deb dependencies for $deb_file"
	for dep in $depends_spaced
		do
    			pkg info "$dep" >/dev/null 2>&1
    			if [ $? -eq 0 ]; then
     			   	echo_success "Deb dependency '$dep' is installed."
   			else
    				missing_packages="$missing_packages $dep"
        			echo_warning "Deb dependency '$dep' is not installed."
    			fi
	done
	
    	# install missing deb dependencies
	count_missing=$(echo "$missing_packages" | wc -w)
	if [ "$count_missing" -gt 0 ]; then
    		echo_running "Found $count_missing missing deb dependencies packages for $deb_file"
    		echo_running "Installing missing deb dependencies: $missing_packages"
    		echo -e "${YELLOW}-------------------------PKG START-------------------------"
    		pkg install -y $missing_packages
    		if [ $? -eq 0 ]; then
    			echo -e "${YELLOW}--------------------------PKG END--------------------------${RESET_COLOR}"
  			echo_success "Deb dependencies package $missing_packages was installed successfully"
		else
			echo -e "${YELLOW}--------------------------PKG END--------------------------${RESET_COLOR}"
    			echo_warning "Deb dependencies package $missing_packages installation failed"
    			if [ "$force" -eq 0 ]; then
    				echo_warning "Script was interrupted by some deb dependencies installation failure."
    				echo_running "Incase some debs are already installed,the application may not show in the menu"
    				echo_running "Update icon cache"
    				update_icon_cache
    				exit 1
    			else
    				echo_warning "!!!You have enabled force option!!!"
    				echo_warning "Script continue no matter dependencies install or not"
    				echo_warning "You are going to solve the dependencies by yourself"
    			fi
    			
		fi
	else
   		 echo_success "$deb_file does not require any deb dependencies or they are already installed."
	fi
	
	pymissing_packages=""
    	pydepends=$(dpkg-deb -I "$deb_file" | grep -E 'Pydeps' | sed 's/Pydeps://g' | tr -d '[:space:]')  
	pydepends_spaced=$(echo "$pydepends" | tr ',' ' ')
	
	# check which pip depend is not installed
    	echo_running "Checking pip dependencies for $deb_file"
	for pydep in $pydepends_spaced
		do
    			pip show "$pydep" >/dev/null 2>&1
    			if [ $? -eq 0 ]; then
     			   	echo_success "Pip dependency '$pydep' is installed."
   			else
    				pymissing_packages="$pymissing_packages $pydep"
        			echo_warning "Pip dependency '$pydep' is not installed."
    			fi
	done
	
	# install missing pip dependencies
	pycount_missing=$(echo "$pymissing_packages" | wc -w)
	if [ "$pycount_missing" -gt 0 ]; then
    		echo_running "Found $pycount_missing missing pip dependencies packages for $deb_file"
    		echo_running "Installing missing pip dependencies: $pymissing_packages"
    		echo -e "${YELLOW}-------------------------PIP START-------------------------"
    		pip install $pymissing_packages
    		if [ $? -eq 0 ]; then
    			echo -e "${YELLOW}--------------------------PIP END--------------------------${RESET_COLOR}"
  			echo_success "Pip dependencies package $pymissing_packages was installed successfully"
		else
			echo -e "${YELLOW}--------------------------PIP END--------------------------${RESET_COLOR}"
    			echo_warning "Pip dependencies package $pymissing_packages installation failed"
    			if [ "$force" -eq 0 ]; then
    				echo_warning "Script was interrupted by some dependencies installation failure."
    				echo_running "Incase some debs are already installed,the application may not show in the menu"
    				echo_running "Update icon cache"
    				update_icon_cache
    				exit 1
    			else
    				echo_warning "!!!You have enabled force option!!!"
    				echo_warning "Script continue no matter dependencies install or not"
    				echo_warning "You are going to solve the dependencies by yourself"
    			fi
    			
		fi
	else
   		 echo_success "$deb_file does not require any pip dependencies or they are already installed."
	fi

}


install_packages() {
    for inputfile in "$@"; do
        if [ -f "$inputfile" ]; then
        	echo_information "Now installing $inputfile"
        	fix_deb_depends "$inputfile"
        	echo -e "${YELLOW}-------------------------DPKG START-------------------------"
		dpkg -i --force-all "$inputfile"
		echo -e "${YELLOW}--------------------------DPKG END--------------------------${RESET_COLOR}"
        else
            	echo_warning "Error: File '$inputfile' does not exist."
            	exit 1
        fi
    done
}


check_linux_c7_partition() {
  partition="$1"
  if mount | grep -q "$partition"; then
    echo_success "The partition '$partition' is mounted."
  else
    echo_warning "The partition '$partition' is not mounted."
    linux_status_failed=1
  fi
}

check_files() {
    for file in "$@"; do
    	
        if [ ! -f "$file" ]; then
        	echo_warning "File $file not exist,stopping..."
        	exit 1
	fi
	
        if [ "${file##*.}" != "deb" ]; then
            	echo_warning "Error: File '$file' does not have a .deb extension."
            	exit 1
        else
        	architecture=$(dpkg-deb -I "$file" | grep -E 'Architecture' | sed 's/Architecture://g' | tr -d '[:space:]')
        fi
        
        if [ "$architecture" != "freebsd-amd64" ]; then
  		echo_warning "Found none freebsd type deb: '$file' ,stopping"
  		exit 1
  	fi
  	
  	if echo "$file" | grep -q "linux-c7" && [ "$linux_checked" -eq 0 ]; then
  		echo_success "Found the linux-c7 type package"
  		echo_running "Checking linux service and mounted partitions"
  		
  		running_services=$(service -e)
  		if echo "$running_services" | grep -q '/etc/rc.d/linux'; then
  			echo_success "linux service is running"
  		else
  			echo_warning "linux service is not running"
  			linux_status_failed=1
  		fi
  		check_linux_c7_partition "/compat/linux/dev"
  		check_linux_c7_partition "/compat/linux/dev/shm"
  		check_linux_c7_partition "/compat/linux/dev/fd"
  		check_linux_c7_partition "/compat/linux/proc"
  		check_linux_c7_partition "/compat/linux/sys"
  		
  		if [ "$linux_status_failed" -eq 0 ]; then
  			echo_success "Linux c7 service and partition is all ok"
  			linux_checked=1
  		else
  			if [ "$force" -eq 0 ]; then
  				echo_warning "Something is wrong about linux c7 service or partition"
				echo_information "If you have not configured any about linux c7, i can do it for you"
				echo_information "I am going to do these to your system
				
				sysrc linux_enable=YES
				service linux start
				pkg install -y linux-c7 linux-c7-gtk3 
				
				write to /etc/fstab
				#linux c7
				devfs      /compat/linux/dev      devfs      rw,late                    0  0
				tmpfs      /compat/linux/dev/shm  tmpfs      rw,late,size=1g,mode=1777  0  0
				fdescfs    /compat/linux/dev/fd   fdescfs    rw,late,linrdlnk           0  0
				linprocfs  /compat/linux/proc     linprocfs  rw,late                    0  0
				linsysfs   /compat/linux/sys      linsysfs   rw,late                    0  0
				
				"
				
  				echo_information "Please enter 'yes' or 'no': "
				read answer

				case $answer in
    					[Yy]|[Yy][Ee][Ss])
        					echo_running "You entered YES. Applying things to your system..."
        					
        					sysrc linux_enable=YES
						service linux start
						if [ $? -eq 0 ]; then
							echo_success "Service linux start successfully"
						else
							echo_warning "Service linux start failed,stopping..."
							exit 1
						fi
						pkg install -y linux-c7 linux-c7-gtk3
echo "
#linux c7
devfs      /compat/linux/dev      devfs      rw,late                    0  0
tmpfs      /compat/linux/dev/shm  tmpfs      rw,late,size=1g,mode=1777  0  0
fdescfs    /compat/linux/dev/fd   fdescfs    rw,late,linrdlnk           0  0
linprocfs  /compat/linux/proc     linprocfs  rw,late                    0  0
linsysfs   /compat/linux/sys      linsysfs   rw,late                    0  0" >> /etc/fstab
						
						echo_information "Done! please reboot the system"
						exit 1
        					;;
    					[Nn]|[Nn][Oo])
        					echo_information "You entered NO. Stopping..."
        					echo_warning "Please check the imformation above,try to fix it on your own"
        					exit 1
        					;;
    					*)
        					echo "Invalid input. Stopping..."
        					exit 1
        					;;
				esac
  				
  				
  			else
  				echo_warning "!!!You have enabled force option!!!"
    				echo_warning "Script will continue no matter is the linux c7 setup all right"
    				echo_warning "You are going to solve the dependencies by yourself"
  			fi
  		fi
  	fi
    done
}

# Main program entry
check_files "$@"
install_packages "$@"
update_icon_cache
echo_success "All packages depends,installation and icon cache update completed."

