# Goals

There's two things that FPC wants to do. First of all it should be a place where users can manage their inks & pens.

Secondly, we also want to take advantage of having the data of all users in one place and aggregate it somehow to provide additional value to the whole user base. For now that's just a simple list of brands and inks but that's of course only the beginning.

It is important to keep in mind that these two goals are in conflict at times. Allowing users to manage their collection of inks to me means that we don't change the user's data. So if one user wants to call the ink "Callifolio Andrinople" and the next one wants to call it "L'Artisan Pastellier Callifolio Andrinople" they should be free to do so. On the other hand, for clustering entries that refer to the same ink it would be nice if everyone named the inks the same. There are cases where I'm OK with changing entries (like spelling mistakes) but in general that should be kept to a minimum. Instead the system should be enhanced to have the ability to deal with these issues.

# Technology

Most parts of the app are written in Ruby on Rails. The inks part is written using React & Redux with a JSON API (the spec) backend.

# The current state

Both the Ruby and the React code aren't in the best of shape. I was in a rush to get everything released so less tests (if any) were written and the code is also not well designed. I want to change that in the future of course and I will keep an eye on these things from now on. Any additions shouldn't be modelled after how the rest of the code is done. They should be well structured and thoroughly covered by tests.

# How to contribute

I've collected a lot of issues. Most of them are not yet concretely thought out, so please reach out to me before starting to implement anything. Then we can discuss what makes sense and what doesn't. Feel free to also create issues for things that would would like to see get done.

# Licensing

The code base is licensed under the MIT license.
