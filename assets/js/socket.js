import {Socket} from "phoenix"

let socket = new Socket("/socket", {params: {token: window.userToken}})

socket.connect()

// Now that you are connected, you can join channels with a topic:
let channel = socket.channel("twitter:interface", {})

// Get access to DOM elements from their ids
let registerUser = document.getElementById("registerUser")
let loginUser = document.getElementById("loginUser")
let name = document.getElementById("userName")
let password = document.getElementById("password")
let sendTweets = document.getElementById("sendTweetButton")
let tweet = document.getElementById("tweet")
let subscribeUser = document.getElementById("subscribeToUser")
let subscribeButton = document.getElementById("subscribeButton")
let logoutButton = document.getElementById("logout")
let deleteAccountButton = document.getElementById("deleteAccount")
let hash_tag_name = document.getElementById("searchHashtag")
let hash_tag_button = document.getElementById("searchHashtagButton")
let search_user_mention = document.getElementById("searchUserMention")
let search_user_button = document.getElementById("searchUserMentionButton")
let sendMessageButton = document.getElementById("sendMessageButton")
let messageText = document.getElementById("messageText")
let messageReceiver = document.getElementById("messageReceiver")

registerUser.addEventListener('click', e => {
  channel.push('register', {
    username: name.value,
    //Use a hashing algorithm here (authentication method used in the class)
    password: password.value
  });
  // name.value = ""
  // password.value = ""
});

hash_tag_button.addEventListener('click', e => {
  channel.push('search_hashtag', {
    hashy: hash_tag_name.value,
  });
  hash_tag_name.value=""
});

search_user_button.addEventListener('click', e => {
  channel.push('search_username', {
    username: search_user_mention.value,
  });
  search_user_mention.value=""
});

channel.on('register', (payload) => {
  console.log(payload)
  if (payload.reply == "error") {
    $('#error_div').css("display", "block")
    $('#error_text').text(payload.message);
  }
});

loginUser.addEventListener('click', e => {
  channel.push('login', {
    username: name.value,
    password: password.value
  });
  password.value = ""
});

channel.on('login', (payload) => {
  console.log(payload)
  if (payload.reply == "error") {
    $('#error_div').css("display", "block")
    $('#error_text').text(payload.message);
  }

  //Here if payload.reply is equal to ok ie logged in correctly, hide the login register elements and show the user feed
  if (payload.reply == "ok") {
    $('#loginRegisterDiv').css("display", "none")
    $('#error_text').text("");
    $('#logoutDeleteButtons').css("display", "block")
    $("#userHome").css("display", "block")
  }
});

subscribeButton.addEventListener('click', e => {
  channel.push('subscribe', {
    subscriber: name.value,
    subscribe_to: subscribeUser.value
  });
  subscribeUser.value = ""
});

logoutButton.addEventListener('click', e => {
  channel.push('logout', {
    username: name.value,
  });
  $('#logoutDeleteButtons').css("display", "none")
  $("#userHome").css("display", "none")
  $("#loginRegisterDiv").css("display", "block")
});

sendTweets.addEventListener('click', e => {
  channel.push('send_tweet', {
    username: name.value,
    userTweet: tweet.value
  });
  tweet.value = "";
});

channel.on('get_tweets', (payload) => {
  console.log(payload)
});

deleteAccountButton.addEventListener('click', e => {
  channel.push('deleteAccount', {
    username: name.value,
    password: password.value
  });
  $('#logoutDeleteButtons').css("display", "none")
  $("#userHome").css("display", "none")
  $("#loginRegisterDiv").css("display", "block")
});

channel.on('receive_tweets', (payload) => {
  console.log(payload);
  //Create a child of user feed's dom element
  let pTag = document.createElement('p')
  pTag.style.margin = "0 0"
  pTag.innerHTML = `<b style="color: #00ACEE": > Tweet by ${payload.tweet_sender}:</b>  ${payload.tweet}`
  let reButton = document.createElement('button')
  reButton.classList.add("btn", "btn-sm", "buttons")
  reButton.style.height = "1.8rem"
  reButton.style.lineHeight = "1.8rem"
  reButton.style.margin = "0 20px"
  reButton.innerText = "Retweet"

  pTag.append(reButton)
  let userFeed = document.getElementById("userFeed")
  userFeed.append(pTag);

  reButton.addEventListener('click', () => {
    console.log('retweet button clicked')
    channel.push("send_retweet", {
      originalTweetSender: payload.tweet_sender, 
      reTweeter: name.value, 
      tweet: payload.tweet
    });
  });
});

channel.on('receive_retweets', (payload) => {
  console.log('In the retweets event', payload);
  let pTag = document.createElement('p')
  pTag.style.margin = "0 0"
  pTag.innerHTML = `<b style="color: #00ACEE": > User ${payload.retweeter} retweeted user ${payload.origTweeter}'s tweet:</b> ${payload.tweet}`
  let userFeed = document.getElementById("userFeed")
  userFeed.append(pTag);
})

channel.on('receive_response', payload => {
  console.log(payload);
  $('#userFeed').append(`<p style="margin: 0 0"><b style="color: #00ACEE": >${payload.message} </b>  ${payload.result}<br>`);
});

sendMessageButton.addEventListener('click' , e => {
  channel.push('sendMessage', {
    username: name.value,
    messageReceiver: messageReceiver.value,
    message: messageText.value
  });
});

channel.on('receive_message', (payload) => {
  console.log(payload);
  $('#userFeed').append(`<p style="margin: 0 0"><b style="color: #00ACEE": >${payload.sender} send a message : </b>  ${payload.message}<br>`);
});

channel.join()
  .receive("ok", resp => { console.log("Joined successfully", resp) })
  .receive("error", resp => { console.log("Unable to join", resp) })

export default socket