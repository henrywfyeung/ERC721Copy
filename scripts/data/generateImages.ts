import hre from "hardhat";
import BigNumber from "bignumber.js";
import { BUNDLR_URL, IMAGE_CACHE } from '../../utils/constants';

import fs from 'fs';
var mime = require('mime');

import Bundlr from "@bundlr-network/client";

let imageFolder = './scripts/data/assets/images/';
let imageList = fs.readdirSync(imageFolder);

let currency: Record<string, string> = {
    'polygon': 'matic'
};

let bundlr: Bundlr;
let cache: Array<Record<string, Buffer | string>> = [];

const initBundlr = async () => {
    bundlr = new Bundlr(BUNDLR_URL, currency[hre.network.name], process.env.PRIVATE_KEY!);
    try {
      // Check for valid bundlr node
      await bundlr.utils.getBundlerAddress(currency[hre.network.name]);
    } catch {
      console.log(`Failed to connect to bundlr ${BUNDLR_URL}`);
      return;
    }
    
    console.log(`Connected to ${BUNDLR_URL}`);
}

const checkBalance = async (): Promise<BigNumber> => {
    return await bundlr?.getBalance(bundlr.address);
}

// top up fund to bundlr account
const fund = async (value: BigNumber) => {
    if (bundlr) {
        console.log("Funding...");
        // const value = parseInput(fundAmount)
        if (!value) return;
        await bundlr.fund(value)
        .then(res => { console.log(`Funded ${res?.target}. tx ID : ${res?.id}`)})
        .catch(e => {
            console.log(`Error: Failed to fund - ${e.data?.message || e.message}`)
        })
    }
};

const arweaveImageUploads = async (index: number): Promise<BigNumber> => {
    
    // const img_url = faker.image.avatar();
    // const resp = await axios.get(img_url, {
    //     responseType: 'arraybuffer'
    //   });
    // let contentType = resp.headers['content-type'];
    // let imageData = Buffer.from(resp.data, 'binary');

    let fileName = imageFolder + imageList[index];
    var imageData = fs.readFileSync(fileName, null).buffer as Buffer;
    var contentType = mime.getType(fileName);

    
    let tx = bundlr?.createTransaction(imageData, {tags: [{name: "Content-Type", value: contentType}]});
    // cache the files
    cache.push({data: imageData, type: contentType});

    let price = await bundlr?.utils.getPrice(currency[hre.network.name] as string, tx!.size);
    return price;
}

const newImages = async (count: number): Promise<BigNumber | void> => {

    let range = [...Array(count).keys()];
    let prices: BigNumber[] = [];

    return Promise.all(
        range.map(( async (i) => {
            prices.push(await arweaveImageUploads(i));
        }))
    ).then(
        () => {
          return prices.reduce((i: BigNumber, j: BigNumber) => i.plus(j) , BigNumber(0));
        }
    ).catch(
        (e) => console.log(e)
    )
}

export async function generateImages(count: number): Promise<string[]> {
  
  // get existing images number (from JSON { images: [arid1, ...] })
  let existingImages: any = {images: []};
  if (fs.existsSync(IMAGE_CACHE)) {
    existingImages = JSON.parse(fs.readFileSync(IMAGE_CACHE).toString());
  }

  if (existingImages.images.length >= count) {
    return existingImages.images.slice(0,count);
  }

  if (hre.network.name == 'hardhat') {
     throw Error('Please switch to polygon for image upload to Arweave');
  }

  // generate images with faker and find out the total size of the images with bundlr
  let imagesToGenerate = count >= existingImages.images.length ? count - existingImages.images.length : 0;
  console.log("Images to Generate: ", imagesToGenerate);

  // get new image data
  await initBundlr();
  let price = await newImages(imagesToGenerate);

  // check fund and transfer the price (with a little bit of overhead)
  let difference = (price!).minus(await checkBalance());
  console.log("Prev Balance: ", await checkBalance());

  if (difference.gt(0)) {
    console.log("Roughly Required: " + difference);
    console.log("To be Funded: " + difference.multipliedBy(1.2).integerValue());
    await fund(difference.multipliedBy(1.2).integerValue());
    console.log("Now Balance: ", await checkBalance());
  }
  
  // launch transactions and pay money
  await Promise.all(
    cache.map(( async (d) => {
        let tx = bundlr?.createTransaction(d.data, {tags: [{name: "Content-Type", value: d.type as string}]});
        await tx?.sign();
        const res = await tx?.upload();
        existingImages.images.push(res.data.id);
    }))
  ).then().catch(
    (e) => console.log(e)
  )

  console.log("Final Balance: ", await checkBalance());

  fs.writeFileSync(IMAGE_CACHE, JSON.stringify(existingImages));

  return existingImages.images;
}

// We recommend this pattern to be able to use async/await everywhere
// and properly handle errors.
if (require.main === module){
  generateImages(parseInt(process.env.IMAGES!)).catch((error) => {
    console.error(error);
    process.exitCode = 1;
  });
}