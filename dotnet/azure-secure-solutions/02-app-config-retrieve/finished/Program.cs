using Microsoft.Extensions.Configuration;
using Microsoft.Extensions.Configuration.AzureAppConfiguration;
using Azure.Identity;

// Set the Azure App Configuration endpoint, replace YOUR_APP_CONFIGURATION_NAME
// with the name of your actual App Configuration service

string endpoint = "https://YOUR_APP_CONFIGURATION_NAME.azconfig.io"; 

// Configure which authentication methods to use
// DefaultAzureCredential tries multiple auth methods automatically
DefaultAzureCredentialOptions credentialOptions = new()
{
    ExcludeEnvironmentCredential = true,
    ExcludeManagedIdentityCredential = true
};

// Create a configuration builder to combine multiple config sources
var builder = new ConfigurationBuilder();

// Add Azure App Configuration as a source
// This connects to Azure and loads configuration values
builder.AddAzureAppConfiguration(options =>
{
    
    options.Connect(new Uri(endpoint), new DefaultAzureCredential(credentialOptions));
});

// Build the final configuration object
try
{
    var config = builder.Build();
    
    // Retrieve a configuration value by key name
    Console.WriteLine(config["Dev:conStr"]);
}
catch (Exception ex)
{
    Console.WriteLine($"Error connecting to Azure App Configuration: {ex.Message}");
}