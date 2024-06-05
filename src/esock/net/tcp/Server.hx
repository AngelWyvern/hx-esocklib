package esock.net.tcp;

import esock.events.EventHandler;
import haxe.io.Error;
import sys.net.Host;
import sys.net.Socket as BaseSocket;

/**
 * An event-based TCP server socket implementation.
 * 
 * @event onListening Dispatches whenever this socket starts listening for new connections.
 * @event onConnection Dispatches whenever a new socket has connected to this socket.
 * @event onError Dispatches whenever an error has occurred.
 * @event onClose Dispatches whenever this socket is closed.
 */
class Server extends EventHandler<ServerEvent>
{
	private var __socket:BaseSocket;
	private var __clients:Array<Socket>;

	/** Whether or not this socket is bound to an address and port number. */
	public var bound(default, null):Bool;
	/** Whether or not this socket is actively listening for connections. */
	public var listening(default, null):Bool;
	/** Whether or not this socket is currently closed. */
	public var closed(get, never):Bool;
	private inline function get_closed():Bool
		return __socket == null;

	/** The IP address this socket is bound to. */
	public var localAddress(get, never):Null<String>;
	private function get_localAddress():Null<String>
	{
		if (__socket != null)
		{
			final host = __socket.host();
			if (host != null)
				return host.host.toString();
		}
		return null;
	}
	/** The port this socket is bound to. */
	public var localPort(get, never):Null<Int>;
	private function get_localPort():Null<Int>
	{
		if (__socket != null)
		{
			final host = __socket.host();
			if (host != null)
				return host.port;
		}
		return null;
	}

	public function new()
	{
		bound = false;
		listening = false;
	}

	/**
	 * Closes the socket.
	 * Data cannot be read from or written to after the socket has been closed.
	 * 
	 * The socket may be reused by calling either `bind()` or `listen()` again.
	 * 
	 * @param hadError Marks that the socket is being closed due to an error.
	 * @throws Closed Operation attempted on a closed socket.
	 */
	public function close(hadError:Bool = false):Void
	{
		if (closed)
			throw SocketError.Closed;

		try
		{
			__socket.close();
		}
		catch (e:Dynamic)
		{
			// Ignore errors
		}

		__socket = null;
		__clients = null;
		bound = listening = false;

		dispatch(onClose, hadError);
	}

	/**
	 * Binds this socket to the given IP address and port number.
	 * 
	 * @param port The port number to bind this socket to. If set to `0` (default), the next available system port is bound.
	 * @param address The IP address to bind this socket to. If set to `"0.0.0.0"` (default), the socket will listen on all available IPv4 addresses. If set to `"::"`, the socket will listen on all available IPv6 addresses.
	 * @throws OutsideRange A property value was out of bounds.
	 * @throws BindFailure A bind operation on a socket failed.
	 * @throws BadArgument An invalid argument was given in a socket operation.
	 */
	public function bind(port:Int = 0, address:String = '0.0.0.0'):Void
	{
		if (port < 0x0 || port > 0xFFFF)
			throw SocketError.OutsideRange;

		if (closed)
			open();

		try
		{
			final host:Host = new Host(address);
			__socket.bind(host, port);
			bound = true;
		}
		catch (e:Dynamic)
		{
			switch (e)
			{
				case "Bind failed":
					throw SocketError.BindFailure;
				case "Unresolved host":
					throw SocketError.BadArgument;
			}

			close(true);
		}
	}

	/**
	 * Starts listening for new TCP connections on this socket.
	 * 
	 * @param queue The max length of pending connections before new connections are automatically denied. If set to `0` (default), the system max length is used instead.
	 * @throws OutsideRange A property value was out of bounds.
	 */
	public function listen(queue:Int = 0):Void
	{
		if (queue < 0)
			throw SocketError.OutsideRange;
		else if (queue == 0)
			queue = 0x7FFFFFFF;

		if (closed)
			open();

		__socket.listen(queue);
		listening = true;

		dispatch(onListening);
	}

	/**
	 * Polls the socket for new clients and any incoming data.
	 * 
	 * This function should be called within a loop, whether it be in a `while (true)` loop
	 * in main, another `while` loop in its own thread, or during a game update cycle (e.g.
	 * `Event.ENTER_FRAME` for OpenFL targets).
	 * 
	 * Any connected clients will automatically be polled upon calling this function, so
	 * adding their poll functions to your loop is unnecessary.
	 * 
	 * Failing to call this function will result in an unspecified behavior.
	 */
	public function poll():Void
	{
		var s:BaseSocket = null;

		try
		{
			s = __socket.accept();
		}
		catch (e:Error)
		{
			if (!isListenedTo(onError))
				throw SocketError.ListenFailure;
			dispatch(onError, SocketError.ListenFailure);
			close(true);
			return;
		}
		catch (e:Dynamic)
		{
			// Do nothing
		}

		if (s != null)
		{
			var client:Socket = Socket.fromBaseSocket(s);
			__clients.push(client);
			dispatch(onConnection, client);
		}

		var disconnected:Array<Int> = [];
		for (i in 0...__clients.length)
		{
			if (__clients[i].closed)
				disconnected.push(i);
			else
				__clients[i].poll();
		}
		while (disconnected.length > 0)
			__clients.splice(disconnected.pop(), 1); // Remove in reverse order to prevent indice shifting
	}

	private inline function open():Void
	{
		__socket = new BaseSocket();
		__socket.setBlocking(false);
		__socket.setFastSend(true);
		__clients = [];
	}
}

enum ServerEvent
{
	onListening;
	onConnection;
	onError;
	onClose;
}