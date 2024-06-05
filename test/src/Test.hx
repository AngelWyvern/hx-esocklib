package;

import esock.net.SocketError;
import esock.net.tcp.Socket as TcpSocket;
import esock.net.tcp.Server as TcpServer;
import esock.net.udp.Socket as UdpSocket;
import haxe.io.Bytes;
import sys.thread.Thread;

class Test
{
	static var mode:Mode = null;

	static function main()
	{
		setup_mode();
		setup_socket();
	}

	static function setup_mode():Void
	{
		var l:Array<Mode> = Mode.createAll();
		
		var opts:String = 'Select a mode to test:\n\n';
		for (i in 0...l.length)
			opts += '${i + 1}. ${l[i].getName()}\n';
		opts += '\nQ. Quit\n\n> ';

		Sys.print(opts);

		do
		{
			var ln:String = Sys.stdin().readLine();
			if (ln.toLowerCase() == 'q')
				Sys.exit(0);
			
			var index:Null<Int> = Std.parseInt(ln);
			if (index == null || index < 1 || index > l.length)
			{
				Sys.print('Please choose a valid mode!\n');
				continue;
			}

			mode = Mode.createByIndex(index - 1);
		}
		while (mode == null);
	}

	static function setup_socket():Void
	{
		//trace("Current mode is: " + mode.getName());
		switch (mode)
		{
			case TCP_Client_Test:
				final socket:TcpSocket = new TcpSocket();
				socket.timeout = 10;

				socket.addListener(onConnect, () ->
				{
					trace('TCP Socket connected to ${socket.remoteAddress}:${socket.remotePort}');
				});

				socket.addListener(onData, (buffer:Bytes) ->
				{
					final str = buffer.toString();

					trace('Received data from server: $str');
					trace('Hex view: ${buffer.toHex()}');
				});

				socket.addListener(onError, (err:SocketError) ->
				{
					trace('SocketError: ${err.getName()}');
				});

				socket.addListener(onClose, (hadErr:Bool) ->
				{
					trace(hadErr ? 'Socket closed prematurely' : 'Socket closed');
				});

				Sys.print('\nServer address: ');
				var connect:Array<String> = Sys.stdin().readLine().split(':');
				socket.connect(connect[0], Std.parseInt(connect[1]));

				var closing:Bool = false;

				Thread.create(() ->
				{
					while (!socket.closed)
					{
						if (!socket.connected)
						{
							// Wait until connected
							Sys.sleep(.01);
							continue;
						}

						var ln:String = Sys.stdin().readLine();
						if (ln == '/close')
						{
							closing = true;
							socket.close();
						}
						else
						{
							socket.write(ln);
						}
					}
				});

				while (!socket.closed)
				{
					if (!closing) // Thread loops are a little finicky
						socket.poll();
				}

			case TCP_Server_Test:
				final server:TcpServer = new TcpServer();
				server.bind(3000);

				server.addListener(onListening, () ->
				{
					trace('TCP Server listening on ${server.localAddress}:${server.localPort}');
				});

				var nextId:Int = 0;
				server.addListener(onConnection, (client:TcpSocket) ->
				{
					// Note: Do not use this to calculate client IDs in real code,
					// indexes will shift when clients disconnect. This is kept here
					// more or less as a Proof of Concept.
					//final id:Int = @:privateAccess server.__clients.indexOf(client);
					final id:Int = nextId++;

					trace('Client $id connected (${client.remoteAddress}:${client.remotePort})');

					client.addListener(onData, (buffer:Bytes) ->
					{
						final str = buffer.toString();

						trace('Received data from client $id: $str');
						trace('Hex view: ${buffer.toHex()}');

						if (str == 'Ping!')
							client.write('Pong!');
					});

					client.addListener(onError, (err:SocketError) ->
					{
						trace('Client $id SocketError: ${err.getName()}');
					});

					client.addListener(onClose, (hadErr:Bool) ->
					{
						trace(hadErr ? 'Client $id closed prematurely' : 'Client $id closed');
					});
				});

				server.addListener(onError, (err:SocketError) ->
				{
					trace('Server SocketError: ${err.getName()}');
				});

				server.addListener(onClose, (hadErr:Bool) ->
				{
					trace(hadErr ? 'Server closed prematurely' : 'Server closed');
				});

				server.listen();
				while (server.listening)
					server.poll();

			case UDP_Socket_Test:
				final socket:UdpSocket = new UdpSocket();
				socket.bind(6000);
				trace('UDP socket spawned on port ${socket.localPort}');

				socket.addListener(onData, (buffer:Bytes, from:{ address:String, port:Int }) ->
				{
					final str = buffer.toString();

					trace('Received data from ${from.address}:${from.port}: $str');
					trace('Hex view: ${buffer.toHex()}');

					if (str == 'Ping!')
						socket.writeTo('Pong!', from.address, from.port);
				});

				socket.addListener(onError, (err:SocketError) ->
				{
					trace('SocketError: ${err.getName()}');
				});

				while (true)
					socket.poll();
		}
	}
}

enum Mode
{
	TCP_Client_Test;
	TCP_Server_Test;
	UDP_Socket_Test;
}