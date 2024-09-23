// Tracking Server Keys
// These are keys that your server should be set up with so that you can verify communications between objects
// You can generate some via https://cryptotools.net/rsagen

default
{
    state_entry()
    {
        llLinksetDataWrite("trackingPrivateKey", "-----BEGIN RSA PRIVATE KEY-----...-----END RSA PRIVATE KEY-----");
        llLinksetDataWrite("trackingPublicKey", "-----BEGIN PUBLIC KEY-----...-----END PUBLIC KEY-----");
    }
}
