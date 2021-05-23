## Welcome to Baduk Go Weiqi Ratings

The ratings are based on 5005 games from 2020-05-23 to 2021-05-22.

\* Ping is a reference to ancient Chinese Weiqi gradings

Error: syntax: invalid escape sequence





# How to compute predicted win percentange?

White 7.5 komi advantage is estimated to be 33 in Elo and 0.19 in Ping

Black 6.5 komi advantage is estimated to be 3 in Elo and 0.02 in Ping

Using the **Elo Rating** it is

Probability that player with rating `r1` wins over someone with rating `r2` is `1/(1 + 10^((r2-r1)/400))`

Using the **Ping** it is

Probability that player with ping `p1` wins over someone with ping `p2` is `1/(1 + exp^(p2-p1))`

# Info

I tried to set 10 ping to 3800 in rating.

One needs to have played more than 10 games with players who make the list over a 365 day period to make the list (I know the definition is abit recursive, but it works).
