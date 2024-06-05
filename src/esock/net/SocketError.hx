package esock.net;

enum SocketError
{
	/** Operation attempted on a closed socket. */
	Closed;

	/** A property value was out of bounds. */
	OutsideRange;

	/** An invalid argument was given in a socket operation. */
	BadArgument;

	/** A read/write operation on a socket failed. */
	IOFailure;

	/** A bind operation on a socket failed. */
	BindFailure;

	/**	An error occurred during the socket listening for clients. */
	ListenFailure;

	/** Failed to connect to remote server. */
	ConnectionFailure;

	/** Connection to remote server timed out. */
	TimedOut;
}