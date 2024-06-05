package esock.net.tcp;

import esock.events.EventHandler;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.Error;
import sys.net.Host;
import sys.net.Socket as BaseSocket;

/**
 * An event-based TCP client socket implementation.
 * 
 * @event onConnect	Dispatches whenever a new connection has been established.
 * @event onData Dispatches whenever new data is available.
 * @event onError Dispatches whenever an error has occurred.
 * @event onClose Dispatches whenever this socket is closed.
 */
class Socket extends EventHandler<SocketEvent>
{
	private var __socket:BaseSocket;
	private var __buffer:Bytes;
	private var __timestamp:Float;

	/** Whether or not this socket is bound to an address and port number. */
	public var bound(default, null):Bool;
	/**	The connection status of this socket. */
	public var connected(default, null):Bool;
	/** Whether or not this socket is currently closed. */
	public var closed(get, never):Bool;
	private inline function get_closed():Bool
		return __socket == null;

	/** The IP address our side of the socket is bound to. */
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
	/** The port our side of the socket is bound to. */
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

	/** The IP address the remote side of the socket is bound to. */
	public var remoteAddress(get, never):Null<String>;
	private function get_remoteAddress():Null<String>
	{
		if (__socket != null)
		{
			final host = __socket.peer();
			if (host != null)
				return host.host.toString();
		}
		return null;
	}
	/** The port the remote side of the socket is bound to. */
	public var remotePort(get, never):Null<Int>;
	private function get_remotePort():Null<Int>
	{
		if (__socket != null)
		{
			final host = __socket.peer();
			if (host != null)
				return host.port;
		}
		return null;
	}

	/** The max time (in seconds) to wait for a connection to be established. */
	public var timeout:Float = 30;

	public function new()
	{
		__buffer = Bytes.alloc(4096);
		connected = false;
	}

	@:allow(esock.net.tcp.Server)
	private static function fromBaseSocket(socket:BaseSocket):Socket
	{
		socket.setBlocking(false);
		socket.setFastSend(true);

		var esock:Socket = new Socket();
		esock.__socket = socket;
		esock.__timestamp = Sys.time();
		esock.connected = true;

		return esock;
	}

	/**
	 * Closes the socket.
	 * Data cannot be read from or written to after the socket has been closed.
	 * 
	 * The socket may be reused by calling `connect()` again.
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
		connected = false;

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
	 * Initiates a connection with a remote server.
	 * 
	 * @param address the server IP address to connect to
	 * @param port the server port to connect to
	 */
	public function connect(address:String = '127.0.0.1', port:Int = 3000):Void
	{
		if (connected)
			close();
		if (closed)
			open();

		final remoteHost = new Host(address);
		__socket.connect(remoteHost, port);
		__timestamp = Sys.time();
	}

	/**
	 * Polls the socket for any incoming data.
	 * 
	 * This function should be called within a loop, whether it be in a `while (true)` loop
	 * in main, another `while` loop in its own thread, or during a game update cycle (e.g.
	 * `Event.ENTER_FRAME` for OpenFL targets).
	 * 
	 * Failing to call this function will result in an unspecified behavior.
	 */
	public function poll():Void
	{
		var doConnect:Bool = false;
		var doClose:Bool = false;
		
		final timedOut:Bool = Sys.time() - __timestamp > timeout;
		var closedByTimeout:Bool = false;

		if (!connected)
		{
			try
			{
				var sel = BaseSocket.select(null, [__socket], null, 0);
				if (sel.write[0] == __socket)
					doConnect = true;
				else if (timedOut)
					doClose = closedByTimeout = true;
				else
					return;
			}
			catch (e:Dynamic)
			{
				doClose = true;
			}
		}

		if (doConnect)
		{
			var peer:{ host:Host, port:Int } = null;
			try
			{
				peer = __socket.peer();
			}
			catch (e:Dynamic)
			{
				// Do nothing
			}
			if (peer == null)
			{
				if (timedOut)
					doClose = closedByTimeout = true;
				else
					return;
			}
		}
		else if (connected)
		{
			var buf:BytesBuffer = new BytesBuffer();

			try
			{
				var len:Int;
				do
				{
					if ((len = __socket.input.readBytes(__buffer, 0, __buffer.length)) > 0)
						buf.addBytes(__buffer, 0, len);
				}
				while (len == __buffer.length);
			}
			catch (e:Error)
			{
				switch (e)
				{
					case Blocked:
					case Custom(v):
						if (v != Error.Blocked)
							doClose = true;
					default:
						doClose = true;
				}
			}
			catch (e:Dynamic)
			{
				doClose = true;
			}

			if (buf.length > 0)
				dispatch(onData, buf.getBytes());
		}

		if (doClose)
		{
			var failed:Bool = !connected;
			if (failed)
				dispatch(onError, closedByTimeout ? SocketError.TimedOut : SocketError.ConnectionFailure);
			close(failed);
		}
		else if (doConnect)
		{
			connected = true;
			dispatch(onConnect);
		}
	}

	/**
	 * Writes content (in UTF-8) to the socket.
	 * 
	 * @param str Content to write to the socket.
	 * @throws Closed Operation attempted on a closed socket.
	 * @throws IOFailure A read/write operation on a socket failed.
	 */
	public function write(str:String):Void
	{
		if (closed)
			throw SocketError.Closed;

		try
		{
			__socket.output.writeString(str, UTF8);
		}
		catch (e:Error)
		{
			switch (e)
			{
				case Blocked:
				case Custom(Error.Blocked):
				default:
					if (!isListenedTo(onError))
						throw SocketError.IOFailure;
					dispatch(onError, SocketError.IOFailure);
			}
		}
	}

	/**
	 * Writes bytes to the socket.
	 * 
	 * @param b Bytes to write to the socket.
	 * @throws Closed Operation attempted on a closed socket.
	 * @throws IOFailure A read/write operation on a socket failed.
	 */
	public function writeBytes(b:Bytes):Void
	{
		if (closed)
			throw SocketError.Closed;

		try
		{
			__socket.output.writeBytes(b, 0, b.length);
		}
		catch (e:Error)
		{
			switch (e)
			{
				case Blocked:
				case Custom(Error.Blocked):
				default:
					if (!isListenedTo(onError))
						throw SocketError.IOFailure;
					dispatch(onError, SocketError.IOFailure);
			}
		}
	}

	private inline function open():Void
	{
		__socket = new BaseSocket();
		__socket.setBlocking(false);
		__socket.setFastSend(true);
	}
}

enum SocketEvent
{
	onConnect;
	onData;
	onError;
	onClose;
}