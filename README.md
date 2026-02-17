# asp-linux-tools
Linux shell scripts making it easier to install ASP applications on Linux (e.g. Ubuntu)

## install

~~~
wget https://raw.githubusercontent.com/MiHoCode/asp-linux-tools/main/scripts/install_asptools.sh
chmod +x install_asptools.sh
sudo ./install_asptools.sh 
~~~

# tools

## asp_create_service
~~~
asp_create_service.sh <service_name> <service_executable> <port(optional,default=5000)>
~~~
example:
~~~
asp_create_service.sh myapp /srv/myapp/myappexe 5000
~~~

## asp_create_webserver
~~~
asp_create_webserver.sh <webserver:apache2|nginx> <domain> <letsencrypt-email> <port(optional,default=5000)>
~~~
example:
~~~
asp_create_webserver.sh apache2 app.example.com user@example.com 5000
~~~
