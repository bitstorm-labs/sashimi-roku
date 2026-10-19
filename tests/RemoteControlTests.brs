' Off-device tests for source/utils/RemoteControl.bs, run by tests/run.js
' against the transpiled module (out/source/utils/RemoteControl.brs): the
' /socket url, the capabilities body, parsing a server message into the one
' action to take, keep-alive timing, reconnect backoff and the OS gate.
'
' The message fixtures are frames Jellyfin 12.2 actually sent (captured
' 2026-10-18 from /socket after POST /Sessions/{id}/Message, /Playing/Stop and
' /Playing/Pause), so a server-shape assumption that drifts shows up here.

sub main()
    t = { passed: 0, failed: 0 }

    testSocketUrl(t)
    testCapabilities(t)
    testParseStop(t)
    testParseMessage(t)
    testParseKeepAlive(t)
    testParseIgnored(t)
    testMessageSecs(t)
    testKeepAliveTiming(t)
    testBackoff(t)
    testOsGate(t)

    print "passed: "; t.passed; " failed: "; t.failed
    if t.failed = 0 then print "ALL PASSED"
end sub

sub eq(t as object, name as string, actual as dynamic, expected as dynamic)
    same = false
    if type(actual) = type(expected)
        same = (actual = expected)
    else if (type(actual) = "String" or type(actual) = "roString") and (type(expected) = "String" or type(expected) = "roString")
        same = (actual = expected)
    else if (type(actual) = "Integer" or type(actual) = "roInt" or type(actual) = "roInteger") and (type(expected) = "Integer" or type(expected) = "roInt" or type(expected) = "roInteger")
        same = (actual = expected)
    else if (type(actual) = "Boolean" or type(actual) = "roBoolean") and (type(expected) = "Boolean" or type(expected) = "roBoolean")
        same = (actual = expected)
    end if
    if same
        t.passed = t.passed + 1
    else
        t.failed = t.failed + 1
        print "FAIL "; name; ": expected "; expected; " got "; actual
    end if
end sub

sub testSocketUrl(t as object)
    eq(t, "https -> wss", RemoteControl_socketUrl("https://fin.example.ca", "abc123"), "wss://fin.example.ca/socket?deviceId=abc123")
    eq(t, "http with port -> ws", RemoteControl_socketUrl("http://192.168.1.20:9096", "abc"), "ws://192.168.1.20:9096/socket?deviceId=abc")
    eq(t, "scheme any case", RemoteControl_socketUrl("HTTPS://Fin.example.ca", "a"), "wss://Fin.example.ca/socket?deviceId=a")
    eq(t, "base path kept", RemoteControl_socketUrl("https://host/jellyfin", "a"), "wss://host/jellyfin/socket?deviceId=a")
    eq(t, "trailing slashes dropped", RemoteControl_socketUrl("https://host/jellyfin//", "a"), "wss://host/jellyfin/socket?deviceId=a")
    eq(t, "surrounding space trimmed", RemoteControl_socketUrl("  http://h:1  ", "a"), "ws://h:1/socket?deviceId=a")
    eq(t, "device id escaped", RemoteControl_socketUrl("http://h", "a b&c=d"), "ws://h/socket?deviceId=a%20b%26c%3Dd")
    eq(t, "no device id", RemoteControl_socketUrl("http://h", ""), "ws://h/socket")
    eq(t, "not http(s)", RemoteControl_socketUrl("ftp://h", "a"), "")
    eq(t, "no scheme", RemoteControl_socketUrl("fin.example.ca", "a"), "")
    eq(t, "empty", RemoteControl_socketUrl("", "a"), "")
    eq(t, "invalid", RemoteControl_socketUrl(invalid, "a"), "")
end sub

sub testCapabilities(t as object)
    c = RemoteControl_capabilities()
    eq(t, "media control claimed", c.SupportsMediaControl, true)
    eq(t, "one command", c.SupportedCommands.count(), 1)
    eq(t, "it is DisplayMessage", c.SupportedCommands[0], "DisplayMessage")
    eq(t, "plays video", c.PlayableMediaTypes[0], "Video")
    ' The exact JSON the server sees: key names are case-sensitive to it.
    json = FormatJSON(c)
    eq(t, "json has SupportsMediaControl", Instr(1, json, """SupportsMediaControl"":true") > 0, true)
    eq(t, "json has SupportedCommands", Instr(1, json, """SupportedCommands"":[""DisplayMessage""]") > 0, true)
    eq(t, "keepalive frame", RemoteControl_keepAliveMessage(), "{""MessageType"":""KeepAlive""}")
end sub

sub testParseStop(t as object)
    a = RemoteControl_parse("{""MessageType"":""Playstate"",""Data"":{""Command"":""Stop""},""MessageId"":""5d1""}")
    eq(t, "stop", a.kind, "stop")
    a = RemoteControl_parse("{""MessageType"":""Playstate"",""Data"":{""Command"":""stop"",""ControllingUserId"":""u""}}")
    eq(t, "stop any case", a.kind, "stop")
    a = RemoteControl_parse("{""MessageType"":""Playstate"",""Data"":{""Command"":""Pause""}}")
    eq(t, "pause ignored", a.kind, "ignore")
    a = RemoteControl_parse("{""MessageType"":""Playstate"",""Data"":{""Command"":""StopX""}}")
    eq(t, "not quite stop", a.kind, "ignore")
    a = RemoteControl_parse("{""MessageType"":""Playstate"",""Data"":""Stop""}")
    eq(t, "data not an object", a.kind, "ignore")
    a = RemoteControl_parse("{""MessageType"":""Playstate""}")
    eq(t, "no data", a.kind, "ignore")
    ' A Stop spelled as a GeneralCommand is not a Playstate Stop.
    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""Stop""}}")
    eq(t, "general Stop ignored", a.kind, "ignore")
end sub

sub testParseMessage(t as object)
    frame = "{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayMessage"",""ControllingUserId"":""00000000000000000000000000000000"",""Arguments"":{""Header"":""Probe"",""Text"":""Hello from the probe"",""TimeoutMs"":""7000""}},""MessageId"":""ab""}"
    a = RemoteControl_parse(frame)
    eq(t, "message kind", a.kind, "message")
    eq(t, "message header", a.header, "Probe")
    eq(t, "message text", a.text, "Hello from the probe")
    eq(t, "string TimeoutMs honoured", a.secs, 7)

    ' The dashboard's own default header, and no TimeoutMs at all.
    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayMessage"",""Arguments"":{""Header"":""Message from Server"",""Text"":""only text""}}}")
    eq(t, "no timeout kind", a.kind, "message")
    eq(t, "no timeout default secs", a.secs, 10)
    eq(t, "no timeout header", a.header, "Message from Server")

    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayMessage"",""Arguments"":{""Text"":""  just text  ""}}}")
    eq(t, "text only", a.kind, "message")
    eq(t, "text trimmed", a.text, "just text")
    eq(t, "missing header is empty", a.header, "")

    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""displaymessage"",""Arguments"":{""Header"":""H""}}}")
    eq(t, "name any case", a.kind, "message")

    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayMessage"",""Arguments"":{""Header"":"""",""Text"":""  ""}}}")
    eq(t, "empty message ignored", a.kind, "ignore")
    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayMessage""}}")
    eq(t, "no arguments ignored", a.kind, "ignore")
    a = RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayMessage"",""Arguments"":{""Header"":5,""Text"":""t""}}}")
    eq(t, "non-text header dropped", a.header, "")
    eq(t, "non-text header keeps text", a.text, "t")
end sub

sub testParseKeepAlive(t as object)
    a = RemoteControl_parse("{""MessageType"":""ForceKeepAlive"",""Data"":60,""MessageId"":""x""}")
    eq(t, "force keepalive", a.kind, "keepalive")
    eq(t, "force keepalive secs", a.secs, 60)
    a = RemoteControl_parse("{""MessageType"":""ForceKeepAlive"",""Data"":""30""}")
    eq(t, "string window", a.secs, 30)
    a = RemoteControl_parse("{""MessageType"":""ForceKeepAlive""}")
    eq(t, "no window -> default", a.secs, 60)
    a = RemoteControl_parse("{""MessageType"":""ForceKeepAlive"",""Data"":0}")
    eq(t, "zero window -> default", a.secs, 60)
    ' The server's answer to our KeepAlive needs no action.
    a = RemoteControl_parse("{""MessageType"":""KeepAlive"",""Data"":null}")
    eq(t, "keepalive answer ignored", a.kind, "ignore")
end sub

sub testParseIgnored(t as object)
    eq(t, "sessions update", RemoteControl_parse("{""MessageType"":""Sessions"",""Data"":[]}").kind, "ignore")
    eq(t, "user data", RemoteControl_parse("{""MessageType"":""UserDataChanged"",""Data"":{}}").kind, "ignore")
    eq(t, "play command", RemoteControl_parse("{""MessageType"":""Play"",""Data"":{""ItemIds"":[""a""]}}").kind, "ignore")
    eq(t, "other general command", RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""GoHome""}}").kind, "ignore")
    ' Another command that happens to carry Header/Text is still not a message.
    eq(t, "other command with text", RemoteControl_parse("{""MessageType"":""GeneralCommand"",""Data"":{""Name"":""DisplayContent"",""Arguments"":{""Header"":""H"",""Text"":""T""}}}").kind, "ignore")
    eq(t, "not json", RemoteControl_parse("hello").kind, "ignore")
    eq(t, "truncated json", RemoteControl_parse("{""MessageType"":""Playstate"",""Data"":{""Comm").kind, "ignore")
    eq(t, "json array", RemoteControl_parse("[1,2]").kind, "ignore")
    eq(t, "no type", RemoteControl_parse("{""Data"":{""Command"":""Stop""}}").kind, "ignore")
    eq(t, "numeric type", RemoteControl_parse("{""MessageType"":3}").kind, "ignore")
    eq(t, "empty", RemoteControl_parse("").kind, "ignore")
    eq(t, "invalid", RemoteControl_parse(invalid).kind, "ignore")
end sub

sub testMessageSecs(t as object)
    eq(t, "whole seconds", RemoteControl_messageSecs("5000"), 5)
    eq(t, "rounds up", RemoteControl_messageSecs("5001"), 6)
    eq(t, "under a second is one", RemoteControl_messageSecs("200"), 1)
    eq(t, "integer accepted", RemoteControl_messageSecs(3000), 3)
    eq(t, "absent -> default", RemoteControl_messageSecs(invalid), 10)
    eq(t, "zero -> default", RemoteControl_messageSecs("0"), 10)
    eq(t, "negative -> default", RemoteControl_messageSecs("-5"), 10)
    eq(t, "garbage -> default", RemoteControl_messageSecs("soon"), 10)
    eq(t, "capped", RemoteControl_messageSecs("3600000"), 120)
    eq(t, "cap boundary", RemoteControl_messageSecs("120000"), 120)
end sub

sub testKeepAliveTiming(t as object)
    eq(t, "half the window", RemoteControl_keepAliveIntervalMs(60), 30000)
    eq(t, "string window", RemoteControl_keepAliveIntervalMs("40"), 20000)
    eq(t, "no window -> default", RemoteControl_keepAliveIntervalMs(0), 30000)
    eq(t, "floor", RemoteControl_keepAliveIntervalMs(2), 5000)
    eq(t, "not stale at one window", RemoteControl_isStale(60000, 60), false)
    eq(t, "not stale at two windows", RemoteControl_isStale(120000, 60), false)
    eq(t, "stale past two windows", RemoteControl_isStale(120001, 60), true)
    eq(t, "stale uses default window", RemoteControl_isStale(120001, 0), true)
    eq(t, "short window", RemoteControl_isStale(21000, 10), true)
end sub

sub testBackoff(t as object)
    eq(t, "first retry", RemoteControl_backoffMs(1), 2000)
    eq(t, "second", RemoteControl_backoffMs(2), 4000)
    eq(t, "third", RemoteControl_backoffMs(3), 8000)
    eq(t, "fifth", RemoteControl_backoffMs(5), 32000)
    eq(t, "capped", RemoteControl_backoffMs(6), 60000)
    eq(t, "stays capped", RemoteControl_backoffMs(500), 60000)
    eq(t, "zero is first", RemoteControl_backoffMs(0), 2000)
end sub

sub testOsGate(t as object)
    eq(t, "16.0 supported", RemoteControl_osSupported({ major: "16", minor: "0", revision: "4", build: "834" }), true)
    eq(t, "17 supported", RemoteControl_osSupported({ major: "17", minor: "0" }), true)
    eq(t, "15.3 not", RemoteControl_osSupported({ major: "15", minor: "3", revision: "4" }), false)
    eq(t, "no version", RemoteControl_osSupported(invalid), false)
    eq(t, "no major", RemoteControl_osSupported({ minor: "0" }), false)
    eq(t, "error 29", RemoteControl_isNotAllowed({ Error: 29, ErrorMsg: "WebSockets are not allowed" }), true)
    eq(t, "code alone", RemoteControl_isNotAllowed({ Error: 29, ErrorMsg: "" }), true)
    eq(t, "message alone", RemoteControl_isNotAllowed({ Error: 0, ErrorMsg: "WebSockets are NOT ALLOWED" }), true)
    eq(t, "ordinary failure", RemoteControl_isNotAllowed({ Error: 7, ErrorMsg: "Couldn't connect" }), false)
    eq(t, "clean close", RemoteControl_isNotAllowed({ Code: 1000, Reason: "", Error: 0, ErrorMsg: "" }), false)
    eq(t, "no info", RemoteControl_isNotAllowed(invalid), false)
end sub
