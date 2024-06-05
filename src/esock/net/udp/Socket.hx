package esock.net.udp;

import esock.events.EventHandler;
import haxe.io.Bytes;
import haxe.io.BytesBuffer;
import haxe.io.Error;
import sys.net.Address;
import sys.net.Host;
import sys.net.Socket as BaseSocket;
import sys.net.UdpSocket as BaseUdpSocket;

/**
 * An event-based UDP socket implementation.
 * 
 * @event onData Dispatches whenever new data is available.
 * @event onError Dispatches whenever an error has occurred.
 */
class Socket extends EventHandler<SocketEvent>
{
	private var __socket:BaseUdpSocket;
	private var __buffer:Bytes;

	/** Whether or not this socket is bound to an address and port number. */
	public var bound(default, null):Bool;
	/** Allows this socket to send to broadcast addresses. */
	public var broadcast(default, set):Bool;
	private function set_broadcast(value:Bool):Bool
	{
		__socket.setBroadcast(value);
		return broadcast = value;
	}

	/** The IP address our side of the socket is bound to. */
	public var localAddress(get, never):Null<String>;
	private function get_localAddress():Null<String>
	{
		final host = __socket.host();
		if (host != null)
			return host.host.toString();
		return null;
	}
	/** The port our side of the socket is bound to. */
	public var localPort(get, never):Null<Int>;
	private function get_localPort():Null<Int>
	{
		final host = __socket.host();
		if (host != null)
			return host.port;
		return null;
	}

	public function new()
	{
		__socket = new BaseUdpSocket();
		__socket.setBlocking(false);
		__buffer = Bytes.alloc(4096);
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
		}
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
		var doRead:Bool = false;

		try
		{
			var sel = BaseSocket.select([__socket], null, null, 0);
			if (sel.read.length > 0 && sel.read[0] == __socket)
				doRead = true;
		}
		catch (e:Dynamic)
		{
			// Do nothing
		}

		if (doRead)
		{
			var buf:BytesBuffer = new BytesBuffer();
			var addr:Address = new Address();

			try
			{
				var len:Int;
				var lastAddr:{ host:Int, port:Int } = null;
				do
				{
					if ((len = __socket.readFrom(__buffer, 0, __buffer.length, addr)) > 0)
					{
						if (lastAddr != null && (addr.host != lastAddr.host || addr.port != lastAddr.port))
						{
							var host:Host = new Host('127.0.0.1');
							untyped host.ip = lastAddr.host;
							dispatch(onData, buf.getBytes(), { address:host.toString(), port:lastAddr.port });
							buf = new BytesBuffer();
						}
						buf.addBytes(__buffer, 0, len);
						lastAddr.host = addr.host;
						lastAddr.port = addr.port;
					}
				}
				while (len == __buffer.length);
			}
			catch (e:Dynamic)
			{
				// Do nothing
			}

			if (buf.length > 0)
				dispatch(onData, buf.getBytes(), { address:addr.getHost().toString(), port:addr.port });
		}
	}

	/**
	 * Writes content (in UTF-8) to send to a remote socket.
	 * 
	 * @param str Content to write to the socket.
	 * @param address The address of the socket to send data to.
	 * @param port The port of the socket to send data to.
	 * @throws IOFailure A read/write operation on a socket failed.
	 */
	public inline function writeTo(str:String, address:String = '127.0.0.1', port:Int = 3000):Void
	{
		writeBytesTo(Bytes.ofString(str, UTF8), address, port);
	}

	/**
	 * Writes bytes to send to a remote socket.
	 * 
	 * @param b Bytes to write to the socket.
	 * @param address The address of the socket to send data to.
	 * @param port The port of the socket to send data to.
	 * @throws IOFailure A read/write operation on a socket failed.
	 */
	public function writeBytesTo(b:Bytes, address:String = '127.0.0.1', port:Int = 3000):Void
	{
		var addr:Address = new Address();
		addr.host = new Host(address).ip;
		addr.port = port;

		try
		{
			__socket.sendTo(b, 0, b.length, addr);
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
		catch (e:Dynamic)
		{
			if (!isListenedTo(onError))
				throw SocketError.IOFailure;
			dispatch(onError, SocketError.IOFailure);
		}
	}
}

enum SocketEvent
{
	onData;
	onError;
}