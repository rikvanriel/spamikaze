#!/usr/bin/perl
use strict;
use warnings;

use FindBin;
use lib "$FindBin::Bin";
use TestHelper;

use Test::More;

use lib "$FindBin::Bin/../scripts";
use Spamikaze;

TestHelper::load_passivetrap();

# Ensure ignorebounces is enabled
$Spamikaze::ignorebounces = 1;

# --- Tests with ignorebounces enabled ---

# Empty From: <>
ok(from_daemon("From: <>\nSubject: test\n"), 'empty From <> is daemon');

# Return-Path: <>
ok(from_daemon("Return-Path: <>\nSubject: bounce\n"), 'empty Return-Path is daemon');

# MAILER-DAEMON
ok(from_daemon("From: <MAILER-DAEMON\@example.com>\nSubject: bounce\n"), 'MAILER-DAEMON is daemon');
ok(from_daemon("From: MAILER-DAEMON\nSubject: test\n"), 'MAILER-DAEMON without angle bracket');

# postmaster
ok(from_daemon("From: postmaster\@example.com\nSubject: test\n"), 'postmaster is daemon');
ok(from_daemon("From: <postmaster\@example.com>\nSubject: test\n"), 'postmaster with angle bracket');
ok(from_daemon("From: Some Name <postmaster\@example.com>\n"), 'postmaster with display name');

# Mailing list software
ok(from_daemon("From: <majordomo\@lists.example.com>\n"), 'majordomo is daemon');
ok(from_daemon("From: <listar\@example.com>\n"), 'listar is daemon');
ok(from_daemon("From: <ecartis\@example.com>\n"), 'ecartis is daemon');
ok(from_daemon("From: <mailman\@example.com>\n"), 'mailman is daemon');

# Owner/request patterns
ok(from_daemon("From: <list-owner\@example.com>\n"), 'list-owner is daemon');
ok(from_daemon("From: <owner-list\@example.com>\n"), 'owner- prefix is daemon');
ok(from_daemon("From: <list-request\@example.com>\n"), 'list-request is daemon');

# Bounce addresses
ok(from_daemon("From: <bounce-foo\@lyris.example.com>\n"), 'lyris bounce is daemon');
ok(from_daemon("From: <bounce-foo\@list.example.com>\n"), 'list bounce is daemon');
ok(from_daemon("From: <bounce-foo\@mail.example.com>\n"), 'mail bounce is daemon');

# X-AskVersion paganini
ok(from_daemon("X-AskVersion: 1.0 paganini.net\nFrom: test\n"), 'X-AskVersion paganini is daemon');

# Qurb challenge
ok(from_daemon("From: test\nusing a program called Qurb which automatically\n"), 'Qurb is daemon');

# Delivery failure messages
ok(from_daemon("Your mail to foo could not be delivered\n"), 'delivery failure is daemon');
ok(from_daemon("Your message could not be delivered\n"), 'message delivery failure is daemon');
ok(from_daemon("Your email could not be delivered\n"), 'email delivery failure is daemon');

# Virus/security scanners
ok(from_daemon("Message from InterScan Messaging Security Suite\n"), 'InterScan is daemon');
ok(from_daemon("ScanMail for Microsoft Exchange has detected\n"), 'ScanMail is daemon');
ok(from_daemon("VIRUS_WARNING detected\n"), 'VIRUS_WARNING is daemon');
ok(from_daemon("WORM_FOUND in message\n"), 'WORM_FOUND is daemon');
ok(from_daemon("The mail message foo contains a virus\n"), 'contains a virus is daemon');

# Challenge-response
ok(from_daemon("X-ChoiceMail-Registration-Request\n"), 'ChoiceMail is daemon');

# Auto-replies
# Note: the regex is ^Subject:(\w\s)*automat - (\w\s)* needs word-char then space pairs
ok(from_daemon("Subject:automatic reply\n"), 'automatic reply is daemon (no space)');
ok(from_daemon("Subject:automated reply from support\n"), 'automated reply is daemon (no space)');
ok(from_daemon("out of office\n"), 'out of office is daemon');
ok(from_daemon("out of the office\n"), 'out of the office is daemon');
ok(from_daemon("this is an automated response\n"), 'automated response is daemon');
ok(from_daemon("this is an automated reply\n"), 'automated reply body is daemon');
ok(from_daemon("Auto-Submitted: auto-replied\n"), 'Auto-Submitted is daemon');
ok(from_daemon("Delivered-To: Autoresponder\n"), 'Autoresponder is daemon');

# German auto-replies
ok(from_daemon("Automatische Antwort\n"), 'German auto-reply is daemon');
ok(from_daemon("Abwesenheitsnotiz: vacation\n"), 'German Abwesenheitsnotiz is daemon');

# Precedence bulk/junk
ok(from_daemon("Precedence: bulk\n"), 'Precedence bulk is daemon');
ok(from_daemon("Precedence: junk\n"), 'Precedence junk is daemon');

# ezmlm
ok(from_daemon("Hi! This is the ezmlm program.\n"), 'ezmlm is daemon');

# Anti-virus From addresses (regex is From?\s+ without colon, case-sensitive)
ok(from_daemon("From eSafe\@example.com\n"), 'eSafe is daemon');
ok(from_daemon("From MAILsweeper\@example.com\n"), 'MAILsweeper is daemon');
ok(from_daemon("From av-gateway\@example.com\n"), 'av-gateway is daemon');

# Symantec
ok(from_daemon("From: Symantec_AntiSpam\@example.com\n"), 'Symantec AntiSpam is daemon');
ok(from_daemon("From: Symantec_Anti-Virus\@example.com\n"), 'Symantec Anti-Virus is daemon');

# Permanent fatal errors
ok(from_daemon("The following addresses had permanent fatal errors\n"), 'permanent fatal errors is daemon');

# Diagnostic-Code X-Notes
ok(from_daemon("Diagnostic-Code: X-Notes; something\n"), 'Diagnostic-Code X-Notes is daemon');

# Error 24
ok(from_daemon("Error 24: This message does not conform to our\n"), 'Error 24 is daemon');

# Invalid address
ok(from_daemon("Your recent message to foo invalid\n"), 'recent message invalid is daemon');

# Apple ID
ok(from_daemon("From: AppleID\@apple.com\n"), 'AppleID is daemon');

# Group membership
ok(from_daemon("TO BECOME A MEMBER OF THE GROUP\n"), 'group membership is daemon');

# Read receipt
ok(from_daemon("This receipt verifies that the message has been\n"), 'read receipt is daemon');

# YMail
ok(from_daemon("Message-ID:X-YMail-OSG\n"), 'YMail OSG is daemon');

# --- Normal spam should NOT match ---
ok(!from_daemon("From: spammer\@evil.com\nSubject: Buy pills\nBody text\n"), 'normal spam is not daemon');

# --- With ignorebounces disabled ---
$Spamikaze::ignorebounces = 0;
ok(!from_daemon("From: <>\nSubject: test\n"), 'with ignorebounces=0, empty From is not daemon');
ok(!from_daemon("From: MAILER-DAEMON\@example.com\n"), 'with ignorebounces=0, MAILER-DAEMON is not daemon');
ok(!from_daemon("Precedence: bulk\n"), 'with ignorebounces=0, Precedence bulk is not daemon');

# Restore for other tests
$Spamikaze::ignorebounces = 1;

done_testing();
