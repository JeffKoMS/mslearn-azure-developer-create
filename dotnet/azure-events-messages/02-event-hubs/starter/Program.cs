using Azure.Messaging.EventHubs;
using Azure.Messaging.EventHubs.Producer;
using Azure.Messaging.EventHubs.Consumer;
using System.Text;
using dotenv.net;

// Load environment variables from .env file and assign to variables
DotEnv.Load();
var envVars = DotEnv.Read();
string connectionString = envVars["EVENT_HUB_CONNECTION_STRING"];
string eventHubName = envVars["EVENT_HUB_NAME"];

// Check for empty connection string or event hub name
if (string.IsNullOrWhiteSpace(connectionString) || string.IsNullOrWhiteSpace(eventHubName))
{
    Console.WriteLine("Error: EVENT_HUB_CONNECTION_STRING and EVENT_HUB_NAME environment variables must be set.");
    return;
}

// Number of events to be sent to the event hub
int numOfEvents = 3;

// CREATE A PRODUCER CLIENT AND SEND EVENTS



// CREATE A CONSUMER CLIENT AND RECEIVE EVENTS

