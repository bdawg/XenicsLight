
file1='data/data_0203a.fits';
file2='data/data_0203b.fits';


cube1 = fitsread(file1);
cube2 = fitsread(file2);

cube1flat = sum(cube1,3);
cube2flat = sum(cube2,3);

figure(1)
imagesc(cub2flat)
h = imrect;
posn = wait(h);

