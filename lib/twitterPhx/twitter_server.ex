defmodule TwitterPhx.TwitterServer do
    use GenServer
    use Phoenix.Channel
    @me __MODULE__

    def start_link() do
        IO.inspect GenServer.start_link(@me, %{}, name: @me)
    end

    def init(init_state) do
        pid = self()
        create_tables()
        new_state = Map.put_new(init_state, :server_pid, pid)
        {:ok, new_state}
    end

    def create_tables do
        :ets.new(:user, [:set, :public, :named_table])# username, password, subscribers , subscribed to, tweet list, online status;
        :ets.new(:hashtags, [:set, :public, :named_table]) # tag, tweets
    end

    def handle_cast({:add_node_name_to_global_list, pid, name}, state) do
        {_ , clientProcesses} = Map.fetch(state , :clientProcesses)
        clientProcesses = Map.put(clientProcesses , name , pid)
        state = Map.put(state , :clientProcesses, clientProcesses)
        {:noreply, state}
    end

    def handle_call({:register, username , password}, _from, state) do
        password = hashFunctionpassword(password)
        {:reply, add_newuser(username, password), state}
    end

    def handle_call({:login, username, password, user_socket}, _from, state) do
        password = hashFunctionpassword(password)
        {:reply, authenticate(username, password, user_socket), state}
    end

    def handle_call({:logout, username, user_socket}, _from, state) do
        {:reply, logout(username, user_socket), state}        
    end

    def handle_call({:delete_account, username}, _from ,state) do
        {:reply, delete_account(username),state}
    end

    def handle_call({:send_tweet, username, tweet}, _from, state) do
        {:reply, send_tweet(username, tweet), state}
    end

    def handle_call({:unsubscribe_user, unsubscriber, subscribed_to}, _from, state) do
        {:reply, unsubscribe_user(unsubscriber, subscribed_to), state}
    end

    def handle_call({:subscribe_user, subscriber, subscribed_to}, _from, state) do
        {:reply, subscribe_user(subscriber, subscribed_to), state}
    end

    def handle_call({:subscribe_hashtag, subscriber, hashtag}, _from, state) do
        {:reply, subscribe_hashtag(subscriber, hashtag), state}
    end

    def handle_call({:unsubscribe_hashtag, unsubscriber, hashtag}, _from, state) do
        {:reply, unsubscribe_hashtag(unsubscriber, hashtag), state}
    end

    def handle_call({:get}, _from, current_state) do
        {:reply, current_state, current_state}
    end

    def handle_call({:get_tweets_for_user, username}, _from ,state) do   
        {:reply ,get_tweets_for_user_wall(username) , state}
    end

    def handle_call({:get_user_tweets, username},_from,state) do
        {:reply, get_tweets(username) ,state}
    end

    def handle_call({:retweet, origTweeter, reTweeter, tweet}, _from, state) do
        {:reply, retweet(origTweeter, reTweeter, tweet) ,state}
    end

    def handle_call({:searchhashtag, name}, _from, state) do
        {:reply, get_hashtag_posts(name) ,state}
    end

    def handle_call({:searchuser, name}, _from, state) do
        {:reply, get_tweets(name) ,state}
    end

    def handle_call({:sendMessage, sender, receiver, message}, _from, state) do
        {:reply, sendMessage(sender, receiver, message), state}
    end

    def sendMessage(sender, receiver, message) do
        case getUserSocket(receiver) do
            {:ok , socket} ->
                if socket != :null do
                    map = %{}
                    map = Map.put(map, :sender, sender)
                    map = Map.put(map, :message, message)
                    push socket, "receive_message", map
                    {:ok, "Message Sent!"}
                else
                    {:error, "!!user doesn't exist. we can't send your message!!"}
                end
            {:error, message} -> {:ok, message}
        end
    end

    def logout(username, user_socket) do
        case :ets.lookup(:user, username) do
        [{u, p, s1, s2, t,  onlinestatus, user_socket, status}] ->
            if onlinestatus do
                :ets.insert(:user, {u, p, s1, s2, t, false, user_socket, :null})
                {:ok, "Logged out successfully!!"}
            else
                {:error , "!!!!you are not logged in.!!!!"}
            end
        [] ->
            {:error, "User not registered"}
        end
    end
    
    def delete_account(username) do
        if :ets.lookup(:user, username) == [] do
            {:error, "Invalid user. User is not registered"}
        else
            :ets.delete(:user, username)
            {:ok, "!!!!!!!!Account has been deleted successfully!!!!!!!. We will miss you"}
        end
    end       

    def send_tweet(username, tweet) do
        case isLoggedin(username) do
            {:ok, status} ->
                if status do
                    #adding the tweet on the tweeter handle of the user
                    [{username, password , subscriber , subscribing , tweets_list, onlinestatus, user_socket, status}] = :ets.lookup(:user, username)
                    if !Enum.member?(tweets_list, tweet) do
                        :ets.insert(:user, {username, password , subscriber , subscribing ,[tweet | tweets_list] , onlinestatus, user_socket, status})
                    end
                    #adding the hastags in the hashtable
                    allhashtags = Regex.scan(~r/#[á-úÁ-Úä-üÄ-Üa-zA-Z0-9_]+/, tweet)
                    Enum.each( allhashtags, fn([x]) ->
                        case :ets.lookup(:hashtags, x) do
                            [{x, tweets_list}] ->
                                if !Enum.member?(tweets_list, tweet) do                
                                    :ets.insert(:hashtags, {x, [tweet | tweets_list]})
                                end
                            [] -> 
                                :ets.insert_new(:hashtags, {x, [tweet]})
                        end
                    end)
                    #adding the tweets on the wall of tagged users
                    allusernames=  Regex.scan(~r/@[á-úÁ-Úä-üÄ-Üa-zA-Z0-9@._]+/, tweet)
                    Enum.each(allusernames, fn([x]) ->
                        x = String.slice(x,1..-1)
                        case :ets.lookup(:user, x) do
                            [{x, password2 , subscriber2 , subscribing2 , tweets_list2, onlinestatus2, user_socket, status}] ->
                                if !Enum.member?(tweets_list, tweet) do                
                                    :ets.insert(:user, {x,  password2 , subscriber2 , subscribing2 ,[tweet | tweets_list2], onlinestatus2, user_socket, status})
                                end
                            [] -> 
                                IO.puts "User #{x} doesn't exist. !!!!!You can't tag this user!!!"
                        end
                    end)

                    #get the tweet sender's subscriber list, and push socket event
                    [{_, _, subscriber , _, _, _, _, _}] = :ets.lookup(:user, username)
                    numSubscribers = length(subscriber)
                    if numSubscribers > 0 do
                        Enum.each(0..(numSubscribers - 1), fn subs -> 
                            #push tweets to subscribed user's wall
                            {_, currentSubSocket} = getUserSocket(Enum.at(subscriber, subs))
                            map = %{}
                            map = Map.put(map, :tweet, tweet)
                            map = Map.put(map, :tweet_sender, username)
                            push currentSubSocket, "receive_tweets", map
                        end)    
                    end

                    # IO.puts ("Tweet sent by #{username}")
                    _message = {:ok, "Tweet sent!"}
                else
                    # IO.puts "Please login first."
                    _message = {:error, "Please login first"}
                end
            {:error, message} ->
                {:error, message}            
        end
    end

    def retweet(origTweeter, reTweeter, tweet) do
        # No changes in tables, just need to push a socket event
        #Need to get sockets of subscribers of retweeters
        [{_, _, subscriber , _, _, _, _, _}] = :ets.lookup(:user, reTweeter)
        numSubscribers = length(subscriber)
        if numSubscribers > 0 do
            Enum.each(0..(numSubscribers - 1), fn subs -> 
                #push tweets to subscribed user's wall
                {_, currentSubSocket} = getUserSocket(Enum.at(subscriber, subs))
                map = %{}
                map = Map.put(map, :origTweeter, origTweeter)
                map = Map.put(map, :retweeter, reTweeter)
                map = Map.put(map, :tweet, tweet)
                push currentSubSocket, "receive_retweets", map
            end)    
        end
        {:ok, "Retweet Sent!"}
    end

    def getServerState() do
        GenServer.call(@me, {:get})
    end

    def subscribe_hashtag( subscriber, hashtag) do
        case :ets.lookup(:user, subscriber) do
            [{subscriber, password1 , subscribers_list , subscribed_list, tweets_list , onlinestatus}] ->
                if(onlinestatus == true) do
                    case :ets.lookup(:hashtags, hashtag) do
                        [{hashtag, tweets_list2}] ->
                            if !Enum.member?(tweets_list2, hashtag) do 
                                :ets.insert(:user, {subscriber,  password1 , subscribers_list ,[hashtag | subscribed_list], tweets_list , onlinestatus})
                                {:ok, "#{subscriber} have successfully subscribed to #{hashtag}"}
                            else
                                {:error, "#{subscriber} already subscribed to #{hashtag}"}
                            end
                        [] ->
                            {:error , "#{hashtag} doesn't exist. Sorry"}
                    end
                else
                    {:error , "!!!!!You have to login first to subscribe.!!!!!"}
                end
            [] ->
                {:error , "thier is no subscriber exist  by #{subscriber} name. Request denied"}
        end
    end

    def subscribe_user( subscriber, subscribed_to) do
        case :ets.lookup(:user, subscriber) do
            [{subscriber, password1 , subscribers_list , subscribed_list, tweets_list , onlinestatus, user_socket_subscriber, status_subscriber}] ->
                if(onlinestatus == true) do
                    case :ets.lookup(:user, subscribed_to) do
                        [{subscribed_to, password2 , subscribers_list2 , subscribed_list2, tweets_list2 , onlinestatus2, user_socket_subscribe_to, status_subscribe_to}] ->
                            if !Enum.member?(subscribed_list, subscribed_to) do
                                :ets.insert(:user, {subscriber,  password1 , subscribers_list ,[subscribed_to | subscribed_list], tweets_list , onlinestatus, user_socket_subscriber, status_subscriber})
                                :ets.insert(:user, {subscribed_to,  password2 ,[subscriber | subscribers_list2], subscribed_list2, tweets_list2 , onlinestatus2, user_socket_subscribe_to, status_subscribe_to})
                                {:ok, "#{subscriber} have successfully subscribed to #{subscribed_to}"}
                            else
                                {:error, "#{subscriber} already subscribed to #{subscribed_to}"}
                            end
                        [] ->
                            {:error , "User #{subscribed_to} doesn't exist."}
                    end
                else
                    {:error , "You have to login first to subscribe."}
                end
            [] ->
                {:error , "No subscriber exists  by #{subscriber} name. Request denied"}
        end
    end

    def get_tweets_for_user_wall(username) do
        [{_, _, _, following_list ,_ , _, _, _}] = :ets.lookup(:user, username)
         temp = Enum.reduce(following_list,[], fn (x, acc) ->
            if Regex.scan(~r/#[á-úÁ-Úä-üÄ-Üa-zA-Z0-9_]+/, x) != [] do
                [ get_hashtag_posts(x) | acc]
            else
                [ get_tweets(x) | acc] 
            end
        end)
        temp = List.flatten(temp) |> Enum.uniq
        temp
    end

    def get_tweets(username) do
        case :ets.lookup(:user,username) do
            [{_, _, _, _ , tweet_list , _, _, _}] -> tweet_list
            [] -> "#{username} username not found"
        end
    end

    def get_hashtag_posts(hashtag) do
        case :ets.lookup(:hashtags,hashtag) do
            [{ _ , tweet_list }] -> tweet_list
            [] -> "#{hashtag} hastag not found"
        end
    end

    def unsubscribe_user(unsubscriber, subscribed_to) do
        case :ets.lookup(:user, unsubscriber) do
            [{unsubscriber, password1 , subscribers_list , subscribed_list, tweets_list , onlinestatus, pid1}] ->
                if(onlinestatus == true) do
                    case :ets.lookup(:user, subscribed_to) do
                        [{subscribed_to, password2 , subscribers_list2 , subscribed_list2, tweets_list2 , onlinestatus2, pid2}] ->
                            if Enum.member?(subscribed_list, subscribed_to) do
                                :ets.insert(:user, {unsubscriber,  password1 , subscribers_list ,List.delete(subscribed_list,subscribed_to), tweets_list , onlinestatus, pid1})
                                :ets.insert(:user, {subscribed_to,  password2 ,List.delete(subscribers_list2, unsubscriber), subscribed_list2, tweets_list2 , onlinestatus2, pid2})
                                {:ok, "#{unsubscriber} have successfully unsubscribed from #{subscribed_to}"}
                            else
                                {:error, "#{unsubscriber} already unsubscribed from #{subscribed_to}"}
                            end                            
                        [] ->
                            {:error , "#{subscribed_to} doesn't exist."}
                    end
                else
                    {:error , "You have to login first to subscribe."}
                end
            [] ->
                {:error , "No subscriber exists  by #{unsubscriber} name."}
        end
    end

    def unsubscribe_hashtag( unsubscriber, hashtag) do
        case :ets.lookup(:user, unsubscriber) do
            [{unsubscriber, password1 , subscribers_list , subscribed_list, tweets_list , onlinestatus}] ->
                if(onlinestatus == true) do
                    case :ets.lookup(:hashtags, hashtag) do
                        [{hashtag, _tweets_list2}] ->
                            if Enum.member?(subscribed_list, hashtag) do
                                :ets.insert(:user, {unsubscriber,  password1 , subscribers_list ,List.delete(subscribed_list,hashtag), tweets_list , onlinestatus})
                                {:ok, "#{unsubscriber} have successfully unsubscribed to #{hashtag}"}
                            else
                                {:error, "#{unsubscriber} already unsubscribed to #{hashtag}"}
                            end
                        [] ->
                            {:error , "#{hashtag} doesn't exist. Sorry"}
                    end
                else
                    {:error , "You have to login first to subscribe."}
                end
            [] ->
                {:error , "There is no subscriber by #{unsubscriber} name"}
        end
    end

    def add_newuser(userName, password) do        
        if checkuser(userName) do
            {:error, "This user already exists."}
        else
            :ets.insert_new(:user, {userName, password, [], [], [], false, :null, :null})
            {:ok, "New user #{userName} successfully added"}
        end
    end

    def checkuser(username) do
        case :ets.lookup(:user, username) do
            [{_, _, _, _, _, _, _, _}] -> true
            [] -> false
        end
    end

    def authenticate(username, password, user_socket) do
        case :ets.lookup(:user, username) do
            [{username, p, s1 , s2, t, onlinestatus, user_socket_info, status}] -> 
                if onlinestatus == false do
                    if p == password do
                        :ets.insert(:user, {username, p, s1 , s2, t, true, user_socket, user_socket})
                        {:ok, "Logged in successfully!!"}    
                    else
                        {:error, "You have entered a wrong password. Try again!"}                       
                    end
                else
                    {:error, "You are already logged in"}
                end                
            [] -> {:error, "User is not registered. Please register the user."}
        end
    end

    def isLoggedin(username) do
        case :ets.lookup(:user, username) do
            [{_, _, _, _, _, x, _socket, _status}] -> {:ok, x}
            [] -> {:error, "Register first to send the tweets"}
        end        
    end
    
    def hashFunctionpassword(input) do
        :crypto.hash(:sha256, input) |> Base.encode16
    end

    def get() do
        GenServer.call(@me, {:get})
    end

    def getUserSocket(userName) do
        case :ets.lookup(:user, userName) do
            [{_, _, _, _, _, _, user_socket, status}] -> {:ok, user_socket}
            [] -> {:error, "Can't find user socket for this user name."}
        end
    end
end