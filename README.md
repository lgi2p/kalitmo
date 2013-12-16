# Kalitmo

## Installation

#### Install Node.js (on Ubuntu)

	$ sudo apt-get install python-software-properties
	$ sudo add-apt-repository ppa:chris-lea/node.js
	$ sudo apt-get update
	$ sudo apt-get install nodejs nodejs-dev npm

### Install Virtuoso

Download and install Virtuoso 7.0 (http://virtuoso.openlinksw.com/)

Once Virtuoso is installed (say in the directory /usr/local/virtuoso-opensource), Open the file
`/usr/local/virtuoso-opensource/var/lib/virtuoso/db/virtuoso.ini` and add "/tmp" to the line `DirsAllowed`

Start virtuoso

### Install Kalitmo

Go to the kalitmo directory (where the file `package.json` is located) and type:

	$ npm install
	$ npm run-script compile

## Configuration

Edit the `config.json` file to match your needs.

### Loading data

To load data from ITCancer's mysql database, launch `update`

	$ ./update

## Starting Kalitmo

	$ ./kalitmo

Kalimo will be accessible at the following address: http://localhost:4000/public/kalitmo.html


## Deployement

If you want to deploy obirs on a server, you can use pm2 to detach and monitor the process:

	$ sudo npm install -g pm2
	$ pm2 start obirs

To stop obirs, type:

	$ pm2 stop obirs

After that, if you want to launch obirs the other way (say `./obirs`) it may throw and error meaning that the port is already taken. All you have to do is to kill the pm2 daemon:

	$ pm2 kill
	$ ./obirs

Kalimo will be accessible at the following address: http://localhost:4000/public/kalitmo.html


## FAQ

### I have this error:

	events.js:72
	        throw er; // Unhandled 'error' event
	              ^
	Error: listen EADDRINUSE

Kalitmo is already launched on the current port.

To fix the issue, close any Kalitmo instances or change the port number in the file `config.json`.

If you are using pm2, you can kill the daemon like this:

	$ pm2 kill

### I have this error:

	Error: connect ECONNREFUSED
	    at errnoException (net.js:901:11)
    	at Object.afterConnect [as oncomplete] (net.js:892:19)

Virtuoso is not running. Please check your installation.


## License

CeCILL-B FREE SOFTWARE LICENSE AGREEMENT
http://www.cecill.info/licences/Licence_CeCILL-B_V1-en.txt