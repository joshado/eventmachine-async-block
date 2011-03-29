EventMachine Async Bloc 
=======================

Overview
--------

Massively simplify EventMachine code, especially in server-type apps by introducing
chunks of "procedural" code in a green-thread-like manner, whilst actually being
evented, and running above EventMachine's reactor.

Discussion
----------

Bourne mainly from frustration with dealing with callbacks / errbacks within callbacks
it does simulate thread-like behaviour, except "thread" interruption occurs only when
you enter a pseudo blocking (evented) function call. Hence you don't have to go nuts
writing thread-safe data-structures as long as you're reasonably sensible about how
you use them.

Also, it meant I'd actually used callcc for something!

Also, also, by re-implementing IO.select using the evented { ... } cal , you're able to use 
Net::SSH within eventmachine with minimal patching (see net_ssh_over_em.rb).

Just make sure you call procedural { ssh.loop } at some point so it thinks it's running it's
event-loop.

And finally...
--------------

First prize to whoever works out how to use without any more detail.
Bonus points for adding detail here.

Comments on a postcard, I may put more effort into describing / investigating behaviour and
performance if people think it's useful and a good idea!

TODO: Write a better README



