# <p align="center">hx-esocklib<p><p align="center"><a href="https://lib.haxe.org/p/esocklib"><img src="https://img.shields.io/badge/available_on-haxelib-EA8220?style=for-the-badge&logo=haxe"/></a> <img src="https://img.shields.io/badge/Version-0.0.1-0080FF?style=for-the-badge"> <img src="https://img.shields.io/badge/Early_development-FFD000?style=for-the-badge"></p>

### <p align="center">⚠️ Warning: This library was made to study Haxe networking.<br>This is mostly a Proof of Concept and may not receive many updates.</p>

This is the repository for hx-esocklib (short for Event-Based Socket Library), an alternative implementation for TCP and UDP sockets powered by an event system.

The use of events eliminates the need for manually checking to see if there's any new clients or data while massively simplifying the code writing process.

*Implementation partially based on OpenFL's socket and NodeJS's socket.*

## <p align="center">Basic Usage Samples</p>

### <p align="center">TCP Client</p>

```hx
import esock.net.SocketError;
import esock.net.tcp.Socket;
import haxe.io.Bytes;

var socket:Socket = new Socket();

socket.addListener(onConnect, () ->
{
	trace("Connection established!");

	socket.write("Ping");
});

socket.addListener(onData, (buffer:Bytes) ->
{
	trace("Incoming data: " + buffer.toString());
});

socket.addListener(onError, (err:SocketError) ->
{
	trace("Error: " + err.getName());
});

socket.addListener(onClose, (hadErr:Bool) ->
{
	if (hadErr)
		trace("Socket closed prematurely.");
	else
		trace("Socket closed.");
});

socket.connect("127.0.0.1", 3000);

while (!socket.closed)
	socket.poll();
```

### <p align="center">TCP Server</p>

```hx
import esock.net.SocketError;
import esock.net.tcp.Server;
import esock.net.tcp.Socket;
import haxe.io.Bytes;

var server:Server = new Server();

server.addListener(onListening, () ->
{
	trace("Listening on " + server.localAddress + ":" + server.localPort);
});

server.addListener(onConnection, (client:Socket) ->
{
	trace("Client connected.");

	client.addListener(onData, (buffer:Bytes) ->
	{
		var str:String = buffer.toString();
		trace("Incoming data: " + str);

		if (str == "Ping")
			client.write("Pong");
	});

	client.addListener(onError, (err:SocketError) ->
	{
		trace("Client error: " + err.getName());
	});

	client.addListener(onClose, (hadErr:Bool) ->
	{
		if (hadErr)
			trace("Client closed prematurely.");
		else
			trace("Client closed.");
	});
});

server.addListener(onError, (err:SocketError) ->
{
	trace("Error: " + err.getName());
});

server.addListener(onClose, (hadErr:Bool) ->
{
	if (hadErr)
		trace("Server closed prematurely.");
	else
		trace("Server closed.");
});

server.listen();

while (server.listening)
	server.poll();
```

### <p align="center">UDP Socket</p>

```hx
import esock.net.SocketError;
import esock.net.udp.Socket;
import haxe.io.Bytes;

var socket:Socket = new Socket();

socket.addListener(onData, (buffer:Bytes, from:{address:String, port:Int}) ->
{
	var str:String = buffer.toString();
	trace("Incoming data: " + str);

	if (str == 'Ping')
		socket.writeTo('Pong', from.address, from.port);

});

socket.addListener(onError, (err:SocketError) ->
{
	trace("Error: " + err.getName());
});

while (true)
	socket.poll();
```

## <p align="center">Reference</p>

### <p align="center">Events</p>

#### TCP Socket:

|   Event   |                       Description                        |          Arguments          |
|-----------|----------------------------------------------------------|-----------------------------|
|`onConnect`|Dispatches whenever a new connection has been established.|`()`                         |
|`onData`   |Dispatches whenever new data is available.                |`(buffer:haxe.io.Bytes)`     |
|`onError`  |Dispatches whenever an error has occurred.                |`(err:esock.net.SocketError)`|
|`onClose`  |Dispatches whenever this socket is closed.                |`(hadErr:Bool)`              |

#### TCP Server:

|    Event     |                             Description                             |           Arguments           |
|--------------|---------------------------------------------------------------------|-------------------------------|
|`onListening` |Dispatches whenever this socket starts listening for new connections.|`()`                           |
|`onConnection`|Dispatches whenever a new socket has connected to this socket.       |`(client:esock.net.tcp.Socket)`|
|`onError`     |Dispatches whenever an error has occurred.                           |`(err:esock.net.SocketError)`  |
|`onClose`     |Dispatches whenever this socket is closed.                           |`(hadErr:Bool)`                |

#### UDP Socket:

|  Event  |               Description                |                        Arguments                        |
|---------|------------------------------------------|---------------------------------------------------------|
|`onData` |Dispatches whenever new data is available.|`(buffer:haxe.io.Bytes, from:{address:String, port:Int})`|
|`onError`|Dispatches whenever an error has occurred.|`(err:esock.net.SocketError)`                            |