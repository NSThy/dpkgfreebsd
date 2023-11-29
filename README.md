# dpkgfreebsd
A small tool to fix dependencies and install deb correctlly,created by nsthy  

# install
sudo wget https://github.com/NSThy/dpkgfreebsd/raw/main/dpkgfreebsd.sh -O /usr/local/bin/dpkgfreebsd && sudo chmod +x /usr/local/bin/dpkgfreebsd  

# information
Usage: 	dpkgfreebsd <inputfile1.deb> <inputfile2.deb> <inputfile3.deb>...   
Option:	-f	#ignore dependencies  

Freebsd's pkg system is difficult to use,but Debian's deb system is easy to use,so i found a way to combine them together  
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
