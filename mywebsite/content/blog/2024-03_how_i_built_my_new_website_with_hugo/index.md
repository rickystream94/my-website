---
title: "How I built my new blog with Hugo and Azure Static Web Apps"
date: 2024-03-02
topics: ['Web Development', 'Microsoft Azure']
featureImage: "https://richmondwebmedia.blob.core.windows.net/media/static_assets/logo.png"
---

## Background

Since 2016, I used to have a hosting plan with [Aruba](https://www.aruba.it/), and I was using **Wordpress** mainly because of its convenience as a CMS.
To a certain extent, the idea of using a CMS made sense for an individual like me, who wanted to invest more time on the creativity aspect, while spending little to no time on development and maintenance overhead.
I do believe Wordpress is quite powerful and there's really no limit to what you can create with it, and I'm not even considering the extra boost you get once you start integrating plugins.
Therefore, for quite a while, I found myself happy with this setup.
However, considering the relatively small amount of new contents I was publishing, I realized over the years that using a CMS for a personal portfolio website had more drawbacks than benefits (relatively slow performance, extra cost for a database, need of a backend, just to name a few).

In 2023, I decided I had enough of Wordpress, and wanted to host my (new) website on **Azure** and move my domain to a new provider. While doing so, I accidentally nuked the website, and I could not recover anything but the database content (phew!).
Don't ask me how this happened and why I didn't keep a local backup 😢. But at least this was an incentive to get started from scratch.

Until that point, I had been out of the web development scene for quite a while, without ever putting my hands on more advanced and trendy frameworks that I could just hear about.
What I really hoped for though, was to get my website up and running again relatively quickly, and:
1. without using a CMS
1. with neither a backend nor a database, mainly to remove unnecessary costs and keep the website as slim and fast as possible
1. without (much) coding
1. with a relatively high level of control over the contents and the "look and feel".

This is how I got to learn a bit about _static site generators_ and technologies like Tailwind CSS, which all sounded appealing and suitable to my scenario. And I also knew I wanted to host my new website on Azure.
And that's how it all started...

## Tech stack

* [Hugo Framework](https://gohugo.io/): is a fast, modern and open-source static site generator written in Go, and designed to make website creation fun again. You can read more about Hugo [here](https://gohugo.io/about/what-is-hugo/).
You can explore a large variety of [themes/templates](https://themes.gohugo.io/), arranged by category.
* [Blowfish](https://blowfish.page/): was the Hugo blog theme I chose, and I was amazed by how easy it was to customize it and create/edit content.

I quickly perceived Hugo as a game changer, and the reasons listed in [_Who should use Hugo?_](https://gohugo.io/about/what-is-hugo/#who-should-use-hugo) in the official docs resonated with me:

> Hugo is for people that prefer writing in a text editor over a browser.
>
> Hugo is for people who want to hand code their own website without worrying about setting up complicated runtimes, dependencies and databases.
>
> Hugo is for people building a blog, a company site, a portfolio site, documentation, a single landing page, or a website with thousands of pages.

Furthermore, I enjoy a lot the local development experience:
1. The `hugo server` command runs a light Hugo server to serve your website on `localhost:1313`.
1. While the server is running, you can work on updating your website content: editing **Markdown** files, adding/removing image files and so on. I use **Visual Studio Code** for this purpose.
1. Hugo rebuilds your site locally whenever it detects changes, the open web pages in the browser are automatically refreshed and you can instantly see the results. This is _so cool_!
1. Markdown files support HTML tags, therefore if you want to achieve something that is either not so straightforward or not supported in native Markdown, you can always fallback to raw HTML.

## Hosting and deployment

* The whole website is under source control on **GitHub**:
    {{< github repo="rickystream94/my-website" >}}
* To keep the repository as "light" as possible, I am storing most media files in an external [Azure Storage BLOB container](https://learn.microsoft.com/en-us/azure/storage/blobs/storage-blobs-introduction).
* [Azure Static Web App](https://learn.microsoft.com/en-us/azure/static-web-apps/): is an offer from Azure which allows you to build modern web applications that automatically publish to the web as your code changes.
* Thanks to this [documentation](https://learn.microsoft.com/en-us/azure/static-web-apps/publish-hugo), it was really straightforward to setup a **GitHub Actions** workflow that would re-publish the website automatically to my Static Web App resource, whenever a new commit in `master` branch is detected.

## Logo

And if you're curious about how I created the logo for this website... You should ask [**Microsoft Copilot**](https://copilot.microsoft.com/) and its **Image Designer** feature 😁
I only had to help myself with Photoshop to fine-tune the AI generated result:

![AI generated website logo](https://richmondwebmedia.blob.core.windows.net/media/static_assets/logo.png)