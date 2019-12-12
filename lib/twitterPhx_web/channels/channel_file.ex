defmodule TwitterPhxWeb.ChannelFile do
    use Phoenix.Channel
    alias TwitterServerFrontEnd
    :observer.start
  
    def join("twitter:interface", _payload, socket) do
      {:ok, socket}
    end
  
    def handle_in("register", payload, socket) do 
      username = Map.get(payload, "username")
      password = Map.get(payload, "password")
      map = %{}
      case IO.inspect GenServer.call(TwitterPhx.TwitterServer, {:register, username, password, "userpid"}) do
        {:ok, msg} ->
          map = Map.put(map, :reply, :ok)
          map = Map.put(map, :message, msg)
          push socket, "register", map
          {:reply, {:ok, msg}, socket}
        {:error, msg} ->
          map = Map.put(map, :reply, :error)
          map = Map.put(map, :message, msg)
          push socket, "register",  map
          {:reply, {:error, msg}, socket}
      end      
      {:noreply, socket}
    end

    def handle_in("login", payload, socket) do
      username = Map.get(payload, "username")
      password = Map.get(payload, "password")
      map = %{}
      case IO.inspect GenServer.call(TwitterPhx.TwitterServer, {:login, username, password,"client_pid"}) do
        {:ok, msg} ->
          map = Map.put(map, :reply, :ok)
          map = Map.put(map, :message, msg)
          push socket, "login", map
          {:reply, {:ok, msg}, socket}
        {:error, msg} ->
          map = Map.put(map, :reply, :error)
          map = Map.put(map, :message, msg)
          push socket, "login",  map
          {:reply, {:error, msg}, socket}
      end      
      {:noreply, socket}
    end
    
    def handle_in("logout", payload, socket) do
      username = Map.get(payload, "name")      
      case IO.inspect GenServer.call(TwitterPhx.TwitterServer, {:logout, username,"client_pid"}) do
        {:ok, msg} ->
          {:reply, {:ok, msg}, socket}
        {:error, msg} ->
          {:reply, {:error, msg}, socket}
      end
      {:noreply, socket}
    end

    def handle_in("follow", payload, socket) do
      subscriber = Map.get(payload, "following")
      subscribed_to = Map.get(payload, "follower")      
      case IO.inspect GenServer.call(TwitterPhx.TwitterServer, {:subscribe_user, subscriber, subscribed_to}) do
        {:ok, msg} ->
          {:reply, {:ok, msg}, socket}
        {:error, msg} ->
          {:reply, {:error, msg}, socket}
      end
      {:noreply, socket}
    end

    def handle_in("send_tweet", payload, socket) do
      username = Map.get(payload, "name")
      tweet = Map.get(payload, "tweet")      
      case IO.inspect GenServer.cast(TwitterPhx.TwitterServer, {:send_tweet, username, tweet}) do
        {:ok, msg} ->
          {:reply, {:ok, msg}, socket}
        {:error, msg} ->
          {:reply, {:error, msg}, socket}
      end
      {:noreply, socket}
    end       

    #not sure about this
    def handle_in("send_retweet", payload, socket) do
      username1 = Map.get(payload, "username1")
      username2 = Map.get(payload, "username2")
      tweet = Map.get(payload, "tweet")            
      case IO.inspect GenServer.cast(TwitterPhx.TwitterServer, {:retweet, username1, username2, tweet}) do
        {:ok, msg} ->
          {:reply, {:ok, msg}, socket}
        {:error, msg} ->
          {:reply, {:error, msg}, socket}
      end
      {:noreply, socket}
    end    

    def handle_in("search_hashtag", payload, socket) do      
      hashtag = Map.get(payload, "hashtag")      
      IO.inspect response =  GenServer.call(TwitterPhx.TwitterServer, {:search_hashtag, hashtag})
      msg = "Search result for hashtag #{hashtag} : #{response}"
      push  socket, "receive_response", %{"message" => msg}
      {:noreply, socket}
    end  

    def handle_in("search_username", payload, socket) do
      username = Map.get(payload, "username")      
      IO.inspect response =  GenServer.call(TwitterPhx.TwitterServer, {:search_user, username})
      msg = "Search result for username #{username} : #{response}"
      push  socket, "receive_response", %{"message" => msg}
      {:noreply, socket}
    end  

    def handle_in("receive_tweet", payload, socket) do      
      {:noreply, socket}
    end

  end