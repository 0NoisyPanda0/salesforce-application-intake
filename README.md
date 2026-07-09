# Application Intake — Salesforce Package

This project solves a straightforward problem: 
partners need to submit applications into Salesforce, and the system needs to 
figure out what to do with them. I built two ways for that to happen, a form 
that anyone can fill out on a public website, and a back-channel connection for 
external systems that send data automatically. Both roads lead to the same place, 
which is the core of how I structured this.

When an application comes in, the first question the system asks is "do we already 
know this company?" If yes, it creates an Opportunity — because there's already a 
relationship worth tracking. If not, it creates a Lead — because this is a new 
conversation that someone needs to follow up on. That matching logic tries to be 
smart about it: it looks for a Tax ID first since that's a hard identifier, and 
falls back to the company name if there's no Tax ID. Either way, every record that 
gets created is stamped with where it came from, so the team always knows whether 
a submission walked through the front door or came in through an integration.

A few things I made deliberate calls on and want to be upfront about. I kept the 
matching intentionally strict — if the company name isn't an exact match, the 
system creates a Lead rather than guessing and potentially attaching a submission 
to the wrong account. A wrong Opportunity is harder to clean up than a Lead sitting 
in a queue. I also made sure that if something goes wrong — bad data, a system 
hiccup, anything — the error never leaks internal details back to whoever submitted 
the form. The system fails gracefully and logs the details privately for the team 
to investigate.

The one thing I knowingly left out is protection against duplicate submissions. If 
an external system sends the same application twice — which happens more than you'd 
think when network timeouts are involved — the current setup will create two records. 
Fixing that properly requires agreeing on a few things with the team first: who 
generates the unique submission ID, how long do we remember it, and what do we send 
back on a retry? Those are product decisions, not just engineering ones, so I called 
it out here rather than quietly implementing something that only looks correct.
