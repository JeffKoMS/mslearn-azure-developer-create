using Azure;
using Azure.Identity;
using Azure.Storage.Queues;
using Azure.Storage.Queues.Models;
using System;
using System.Threading.Tasks;

// Create a unique name for the queue
// TODO: Replace the <YOUR-STORAGE-ACCT-NAME> placeholder 
string queueName = "myqueue-" + Guid.NewGuid().ToString();
string storageAccountName = "<YOUR-STORAGE-ACCT-NAME>";

// ADD CODE TO CREATE A QUEUE CLIENT AND CREATE A QUEUE



// ADD CODE TO SEND AND LIST MESSAGES



// ADD CODE TO UPDATE A MESSAGE AND LIST MESSAGES



// ADD CODE TO DELETE MESSAGES AND THE QUEUE

