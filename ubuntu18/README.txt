## docker build -t edge_ubuntu18 --no-cache -f Dockerfile.txt .

#### mysqldump --user edge --password=edge userManagement > /tmp/userManagement.dump.sql

### To Run
## docker create --name mysql_ubuntu_data --volume /var/lib/mysql bioedge/edge_ubuntu_mysql
## docker run -d --privileged=true --security-opt "seccomp:unconfined" --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE --volumes-from mysql_ubuntu_data -v /Users/chien-chi/Projects/edge-git:/edge_source -p 80:80 -p 8080:8080 --name edge bioedge/edge_dev 
## docker run -d --privileged=true --security-opt "seccomp:unconfined" --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE --volumes-from mysql_ubuntu_data -v /Users/chien-chi/Docker/EDGE_input:/home/edge/EDGE_input -v /Volumes/Seagate/EDGE/database:/home/edge/database -v /Users/chien-chi/Docker/EDGE_output:/home/edge/EDGE_output -v /Users/chien-chi/Projects/edge-git:/edge_source -p 80:80 -p 8080:8080 --name edge test_edge bash -C "/start.sh"
## docker run -d --privileged=true --security-opt "seccomp:unconfined" --cap-add=SYS_ADMIN --cap-add=SYS_PTRACE --volumes-from mysql_ubuntu_data -p 80:80 -p 8080:8080 --name edge bioedge/edge_dev 
##      
