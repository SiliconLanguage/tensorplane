use usrbio::{Ior, Iov};

fn main() {
    println!("===========================================");
    println!(" TensorPlane Data Plane Accelerator");
    println!(" Starting USRBIO Engine...");
    println!("===========================================");

    let ring = Ior::new(1024, 0xFEEDFACE);
    let buffer = [0u8; 1024];
    let _vector = Iov::new(&buffer, 0x10000000);

    match ring.submit_cmd() {
        Ok(_) => println!("=> Test command submitted to hardware doorbell."),
        Err(e) => println!("=> Hardware error: {}", e),
    }

    println!("===========================================");
}
