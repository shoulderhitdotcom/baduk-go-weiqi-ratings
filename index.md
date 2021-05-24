## Welcome to Baduk Go Weiqi Ratings

The ratings are based on 5008 games from 2020-05-24 to 2021-05-23.

^ Ping is a reference to ancient Chinese Weiqi gradings

Error: UndefVarError: DataFrame not defined





# How to compute predicted win percentange?

White 7.5 komi advantage is estimated to be 33 in Elo and 0.19 in Ping

Black 6.5 komi advantage is estimated to be 3 in Elo and 0.02 in Ping

Using the **Elo Rating** it is

Probability that player with rating `r1` wins over someone with rating `r2` is `1/(1 + 10^((r2-r1)/400))`

Using the **Ping** it is

Probability that player with ping `p1` wins over someone with ping `p2` is `1/(1 + exp^(p1-p2))`
