package esock.events;

import haxe.Constraints;
import haxe.ds.EnumValueMap;

/**
 * The base for event-driven classes.
 * 
 * Takes an enum type to use as a list of events.
 */
class EventHandler<E:EnumValue>
{
	@:noCompletion private var __eventMap:EnumValueMap<E, Array<ListenerDef>> = new EnumValueMap();

	/**
	 * Adds an event listener to this object with the given properties.
	 * 
	 * @param event The event to add the listener to.
	 * @param callback The function to be called upon the event being dispatched.
	 * @param once Whether this listener should only be called once.
	 */
	public function addListener(event:E, callback:Function, once:Bool = false):Void
	{
		if (callback == null)
			return;

		var e:Array<ListenerDef>;
		if ((e = __eventMap.get(event)) == null)
			__eventMap.set(event, e = []); // assign a blank array to both `e` and `__eventMap[event]`
		var def:ListenerDef = { callback:callback, once:once };

		for (d in e)
			if (def.callback == d.callback && def.once == d.once)
				return;

		e.push(def);
	}

	/**
	 * Checks if an event in this object contains a listener with the given properties.
	 * 
	 * @param event The event to search for the listener.
	 * @param callback The function to match with the listener.
	 * @param once If specified, will match to listeners with the given `once` value.
	 * @return `true` if the listener was found, `false` otherwise.
	 */
	public function hasListener(event:E, callback:Function, ?once:Bool):Bool
	{
		var e:Array<ListenerDef> = __eventMap.get(event);
		if (e == null)
			return false;

		for (d in e)
			if (callback == d.callback && (once == null || once == d.once))
				return true;
		return false;
	}

	/**
	 * Checks if an event in this object contains any listeners.
	 * 
	 * @param event The event to perform the check on.
	 * @return `true` if the event has listeners attached to it, `false` otherwise.
	 */
	private function isListenedTo(event:E):Bool
	{
		var e:Array<ListenerDef> = __eventMap.get(event);
		return e != null && e.length > 0;
	}

	/**
	 * Removes an event listener in this object with the given properties.
	 * 
	 * @param event The event to remove the listener from.
	 * @param callback The function attached to the listener.
	 * @param once If specified, will only remove listeners with a matching `once` value.
	 */
	public function removeListener(event:E, callback:Function, ?once:Bool):Void
	{
		var e:Array<ListenerDef> = __eventMap.get(event);
		if (e == null)
			return;

		for (i => d in e)
		{
			if (callback == d.callback && (once == null || once == d.once))
			{
				e.splice(i, 1);
				break;
			}
		}
	}

	/**
	 * Dispatches callback execution to all listeners in a given event.
	 * 
	 * @param event The event to dispatch execution from.
	 * @param args Optional arguments to pass to the callbacks.
	 */
	public function dispatch(event:E, ...args:Dynamic):Void
	{
		var e:Array<ListenerDef> = __eventMap.get(event);
		if (e == null)
			return;

		var garbage:Array<Int> = [];
		for (i => d in e)
		{
			switch (args.length)
			{
				case 1:  d.callback(args[0]);
				case 2:  d.callback(args[0], args[1]);
				case 3:  d.callback(args[0], args[1], args[2]);
				case 4:  d.callback(args[0], args[1], args[2], args[3]);
				default: d.callback();
			}
			if (d.once)
				garbage.push(i);
		}
		while (garbage.length > 0)
			e.splice(garbage.pop(), 1); // Remove in reverse order to prevent indice shifting
	}
}

private typedef ListenerDef =
{
	var callback:Function;
	var once:Bool;
};