// add your web client id to link.content (https://console.cloud.google.com/apis/credentials)
const link = document.createElement('meta');
link.setAttribute('name', 'google-signin-client_id');
link.content = "YOUR_WEB_CLIENT_ID";
document.getElementsByTagName('head')[0].appendChild(link);
